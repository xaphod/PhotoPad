//
//  BPPAirprintCollagePrinter.m
//  PhotoPad
//
//  Created by Tim Carr on 2/9/14.
//  Copyright (c) 2014 Tim Carr. All rights reserved.
//

#import "BPPAirprintCollagePrinter.h"

@implementation BPPAirprintCollagePrinter

// TODO:
// test making collages of mixed images - some resize by width

+ (BPPAirprintCollagePrinter *)singleton {
    static dispatch_once_t pred;
    static BPPAirprintCollagePrinter *shared = nil;
    
    dispatch_once(&pred, ^{
        shared = [[BPPAirprintCollagePrinter alloc] init];
    });
    return shared;
}

- (id)init {
    if (self = [super init]) {
        _printerIDs = [NSMutableArray array];
        _lastUsedPrinterIDArrayIndex = -1;
    }
    return self;
}

// public
// creates collages of up to 6 images in a single image
- (bool)printCollage:(NSArray*)images fromUIBarButton:(UIBarButtonItem*)fromUIBarButton {
    if( images.count < 2 ) {
        // must pass in at least 2 images
        NSLog(@"printCollage: must print at least 2 images");
        return NO;
    }
    
    if( ! [[images objectAtIndex:0] isKindOfClass:[UIImage class]] ) {
        // input must be array of UIImage* --- check the first one for sanity
        NSLog(@"printCollage: input must be UIImages");
        return NO;
    }
    
    if( CollageLongsidePixels * 0.25 != CollageShortsidePixels* 0.375 ) {
        // dimensions are not in 4 x 6
        NSAssert(NO, @"Input dimensions (CollageXsidePixels) are not in 6:4 ratio");
        return NO;
    }
    
    NSArray *collageGroupings = [self makeCollageUIImageGroupings:images];
    NSArray *collagesArrayUIImage = [self makeCollageImages:collageGroupings];
    
    UIPrintInteractionController *controller = [UIPrintInteractionController sharedPrintController];
    
    UIPrintInfo *printInfo = [UIPrintInfo printInfo];
    printInfo.outputType = UIPrintInfoOutputPhoto;
    printInfo.jobName = @"Photopad print";
    
    // printers get saved as they are used. if there are printers saved, use them... user must still confirm the choice (iOS limitation)
    if( self.printerIDs.count == 1 ) {
        // use this printer only
        printInfo.printerID = self.printerIDs[0];
        
    } else if( self.printerIDs.count > 1) {
        if( _lastUsedPrinterIDArrayIndex == -1 ) { // if never used
            NSLog(@"printCollage: More than one printer found, for the first time");
            _lastUsedPrinterIDArrayIndex++;
        }
        printInfo.printerID = self.printerIDs[_lastUsedPrinterIDArrayIndex];
        NSLog(@"printCollage: using printer %d - %@", _lastUsedPrinterIDArrayIndex, self.printerIDs[_lastUsedPrinterIDArrayIndex]);
        _lastUsedPrinterIDArrayIndex++;
        if( _lastUsedPrinterIDArrayIndex >= self.printerIDs.count )
            _lastUsedPrinterIDArrayIndex = 0;
    }
    
    controller.printInfo = printInfo;
    controller.printingItems = collagesArrayUIImage;
    
    UIPrintInteractionCompletionHandler completionHandler = ^(UIPrintInteractionController *printController, BOOL completed, NSError *error) {
        
        if( completed ) {
            // save this printer, but only if it is not already saved
            bool newPrinter = YES;
            for( id thisID in self.printerIDs ) {
                if( [printController.printInfo.printerID isEqualToString:thisID] ) {
                    newPrinter = NO;
                    break;
                }
            }
            
            if( newPrinter ) {
                NSLog(@"printCollage, saving selected Printer ID, because it hasn't been seen before: %@",printController.printInfo.printerID);
                [self.printerIDs addObject:printController.printInfo.printerID];
            } else {
                NSLog(@"printerCollage, not saving printer ID because it is already known");
            }
            // TODO: UI confirmation of success here?
        } else {
            if( error )
                NSLog(@"printCollage: printing FAILED! due to error in domain %@ with error code %d", error.domain, (int)error.code);
            else
                NSLog(@"printCollage: printing cancelled by user");
            // TODO: UI confirmation of cancel here?
        }
    };
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        [controller presentFromBarButtonItem:fromUIBarButton animated:YES completionHandler:completionHandler];  // iPad
    }
    else
    {
        [controller presentAnimated:YES completionHandler:completionHandler];  // iPhone
    }
 
    return YES;
}

// private
- (NSArray*)makeCollageUIImageGroupings:(NSArray*)images {
    NSMutableArray *groupedCollages = [NSMutableArray array];      // array of arrays of input images
    int imagesConsumed = 0;                                        // index + counter
    
    // break into pages
    while( TRUE ) {
        // loop exit condition: exactly finished
        if( images.count == imagesConsumed )
            break;
        
        else if( images.count - imagesConsumed <= 6 ) {
            // loop exit condition: between 0 and 6: exactly one last collage
            NSArray *collage = [images subarrayWithRange:NSMakeRange( imagesConsumed, (images.count-imagesConsumed) )];
            [groupedCollages addObject:collage];
            NSLog(@"AirprintCollagePrinter: Made FINAL collage %lu, size is %lu", groupedCollages.count, images.count-imagesConsumed);
            imagesConsumed = (int)images.count;
        } else {
            
            // normal loop case: there's more than 6 to go
            int batchSize = (int)[self getRandomNumberBetween:2 maxNumber:6];
            
            // don't let the last number be a 1, as 1 is not a collage
            if( images.count - (imagesConsumed + batchSize) == 1 ) {
                if( batchSize != 6 )
                    batchSize++;
                else
                    batchSize--;
            }
            
            NSArray *collage = [images subarrayWithRange:NSMakeRange( imagesConsumed, batchSize )];
            [groupedCollages addObject:collage];
            NSLog(@"AirprintCollagePrinter: Made collage %lu, size is %d", groupedCollages.count, batchSize);
            imagesConsumed += batchSize;
        }
    }
    
    NSLog(@"makeCollageUIImageGroupings: returning %lu groups", groupedCollages.count);
    return groupedCollages;
}

// public
- (NSArray*)makeCollageImages:(NSArray*)collages {
    
    NSMutableArray *retval = [NSMutableArray array];
    
    for (id thisID in collages) {
        
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(CollageLongsidePixels, CollageShortsidePixels), YES, 1.0);
        [[UIColor CollageBorderUIColor] setFill];
        UIRectFill(CGRectMake(0, 0, CollageLongsidePixels, CollageShortsidePixels));
        
        NSArray* imagesOfThisCollage = (NSArray*)thisID;
        
        if( imagesOfThisCollage.count == 2 ) {
            // orientation: landscape
            
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[0] rect:CGRectMake(CollageBorderPixels, CollageBorderPixels, (CollageLongsidePixels - (3*CollageBorderPixels) ) / 2, (CollageShortsidePixels - (2*CollageBorderPixels) ) )];
            
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[1] rect:CGRectMake((CollageLongsidePixels/2) + (CollageBorderPixels/2), CollageBorderPixels, (CollageLongsidePixels - (3*CollageBorderPixels) ) / 2, (CollageShortsidePixels - (2*CollageBorderPixels) ) )];
            
        } else if( imagesOfThisCollage.count == 3 ) {
            // all squares
           
            int width1and2 = (CollageLongsidePixels - (3*CollageBorderPixels) ) / 3;
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[0] rect:CGRectMake(CollageBorderPixels, CollageBorderPixels, width1and2, (CollageShortsidePixels - (3*CollageBorderPixels) )/ 2 )];
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[1] rect:CGRectMake(CollageBorderPixels, (CollageShortsidePixels/2) + (CollageBorderPixels/2), width1and2, (CollageShortsidePixels - (3*CollageBorderPixels) )/ 2 )];
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[2] rect:CGRectMake( 2*CollageBorderPixels+width1and2, CollageBorderPixels, (CollageLongsidePixels - (3*CollageBorderPixels) )*2/3, CollageShortsidePixels - (2*CollageBorderPixels))];
            
        } else if( imagesOfThisCollage.count == 4 ) {
            // orientation: **PORTRAIT**

            UIGraphicsEndImageContext();
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(CollageShortsidePixels, CollageLongsidePixels), YES, 1.0);
            [[UIColor CollageBorderUIColor] setFill];
            UIRectFill(CGRectMake(0, 0, CollageShortsidePixels, CollageLongsidePixels));
            
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[0] rect:CGRectMake(CollageBorderPixels, CollageBorderPixels, (CollageShortsidePixels - 3*CollageBorderPixels) / 2, (CollageLongsidePixels - 3*CollageBorderPixels) / 2) ];
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[1] rect:CGRectMake((CollageShortsidePixels/2) + (CollageBorderPixels/2), CollageBorderPixels, (CollageShortsidePixels - 3*CollageBorderPixels) / 2, (CollageLongsidePixels - 3*CollageBorderPixels) / 2) ];
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[2] rect:CGRectMake(CollageBorderPixels, (CollageLongsidePixels/2) + (CollageBorderPixels/2), (CollageShortsidePixels - 3*CollageBorderPixels) / 2, (CollageLongsidePixels - 3*CollageBorderPixels) / 2) ];
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[3] rect:CGRectMake((CollageShortsidePixels/2) + (CollageBorderPixels/2), (CollageLongsidePixels/2) + (CollageBorderPixels/2), (CollageShortsidePixels - 3*CollageBorderPixels) / 2, (CollageLongsidePixels - 3*CollageBorderPixels) / 2) ];
            
        } else if( imagesOfThisCollage.count == 5 ) {
            // orientation: **PORTRAIT**

            UIGraphicsEndImageContext();
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(CollageShortsidePixels, CollageLongsidePixels), YES, 1.0);
            [[UIColor CollageBorderUIColor] setFill];
            UIRectFill(CGRectMake(0, 0, CollageShortsidePixels, CollageLongsidePixels));
            
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[0] rect:CGRectMake(CollageBorderPixels, CollageBorderPixels, (CollageShortsidePixels/2) - CollageBorderPixels - (CollageBorderPixels/2), (CollageLongsidePixels/2) - CollageBorderPixels - (CollageBorderPixels/2)) ];
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[1] rect:CGRectMake((CollageShortsidePixels/2) + (CollageBorderPixels/2), CollageBorderPixels, (CollageShortsidePixels/2) - CollageBorderPixels - (CollageBorderPixels/2), (CollageLongsidePixels - (4*CollageBorderPixels) )/3) ];
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[2] rect:CGRectMake(CollageBorderPixels, (CollageLongsidePixels/2) + (CollageBorderPixels/2), (CollageShortsidePixels/2) - CollageBorderPixels - (CollageBorderPixels/2), (CollageLongsidePixels/2) - CollageBorderPixels - (CollageBorderPixels/2)) ];
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[3] rect:CGRectMake((CollageShortsidePixels/2) + (CollageBorderPixels/2), (CollageLongsidePixels/3) + (CollageBorderPixels/2), (CollageShortsidePixels/2) - CollageBorderPixels - (CollageBorderPixels/2), (CollageLongsidePixels - (4*CollageBorderPixels) )/3) ];
 
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[4] rect:CGRectMake((CollageShortsidePixels/2) + (CollageBorderPixels/2), (CollageLongsidePixels*2/3) + (CollageBorderPixels/2), (CollageShortsidePixels/2) - CollageBorderPixels - (CollageBorderPixels/2), (CollageLongsidePixels - (4*CollageBorderPixels) )/3)];
            
        } else if( imagesOfThisCollage.count == 6 ) {
            // orientation: landscape
            
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[0] rect:CGRectMake(CollageBorderPixels, CollageBorderPixels, (CollageLongsidePixels - (4*CollageBorderPixels)) / 3, (CollageShortsidePixels- (3*CollageBorderPixels)) / 2) ];
            
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[1] rect:CGRectMake((CollageLongsidePixels/3) + (CollageBorderPixels/2), CollageBorderPixels, (CollageLongsidePixels - (4*CollageBorderPixels)) / 3, (CollageShortsidePixels- (3*CollageBorderPixels)) / 2) ];
            
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[2] rect:CGRectMake((CollageLongsidePixels*2/3) + (CollageBorderPixels/2), CollageBorderPixels, (CollageLongsidePixels - (4*CollageBorderPixels)) / 3, (CollageShortsidePixels- (3*CollageBorderPixels)) / 2) ];
            
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[3] rect:CGRectMake(CollageBorderPixels, (CollageShortsidePixels/2) + (CollageBorderPixels/2), (CollageLongsidePixels - (4*CollageBorderPixels)) / 3, (CollageShortsidePixels- (3*CollageBorderPixels)) / 2) ];
            
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[4] rect:CGRectMake((CollageLongsidePixels/3) + (CollageBorderPixels/2), (CollageShortsidePixels/2) + (CollageBorderPixels/2), (CollageLongsidePixels - (4*CollageBorderPixels)) / 3, (CollageShortsidePixels- (3*CollageBorderPixels)) / 2) ];
            
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[5] rect:CGRectMake((CollageLongsidePixels*2/3) + (CollageBorderPixels/2), (CollageShortsidePixels/2) + (CollageBorderPixels/2), (CollageLongsidePixels - (4*CollageBorderPixels)) / 3, (CollageShortsidePixels- (3*CollageBorderPixels)) / 2) ];
        }
        
        UIImage* collageImage = UIGraphicsGetImageFromCurrentImageContext();
        [retval addObject:collageImage];
        NSLog(@"makeCollageImages: adding collage UIImage");
        UIGraphicsEndImageContext();
        
        // TODO: REMOVE THIS DEBUG CODE
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString *appFile = [documentsDirectory stringByAppendingPathComponent:@"collage.JPG"];
        NSData* jpgImage = UIImageJPEGRepresentation(collageImage, CollageJPGQuality);
        [jpgImage writeToFile:appFile atomically:YES];

    } // end for
    
    return retval;
}


// private
- (void)resizeAndDrawInRect:(UIImage*)image rect:(CGRect)rect {
    NSLog(@"resizeAndDrawInRec: calling resize. Src: w:%f h:%f. Draw target x:%f y:%f w:%f h:%f", image.size.width, image.size.height, rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
    UIImage* resizedAndCroppedImage = [self resizeAndCropUIImage:image targetWidth:rect.size.width targetHeight:rect.size.height];
    if( nil == resizedAndCroppedImage ) {
        NSLog(@"Failed to resize image!");
        return;
    }
    [resizedAndCroppedImage drawInRect:(rect)];
}

// private
- (UIImage*)resizeAndCropUIImage:(UIImage*)image targetWidth:(double)targetWidth targetHeight:(double)targetHeight {
    
    CGFloat scale = MAX(targetWidth/image.size.width, targetHeight/image.size.height);
    CGFloat width = image.size.width * scale;
    CGFloat height = image.size.height * scale;
    CGRect imageRect = CGRectMake((targetWidth - width)/2.0f,
                                  (targetHeight - height)/2.0f,
                                  width,
                                  height);
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(targetWidth, targetHeight), YES, 1.0);
    [image drawInRect:imageRect];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

// private
- (NSInteger)getRandomNumberBetween:(NSInteger)min maxNumber:(NSInteger)max
{
    // we don't care about modulo bias
    return min + arc4random() % (max - min + 1);
}

@end
