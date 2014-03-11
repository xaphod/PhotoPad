//
//  BPPAirprintCollagePrinter.m
//  PhotoPad
//
//  Created by Tim Carr on 2/9/14.
//  Copyright (c) 2014 Tim Carr. All rights reserved.
//

#import "BPPAirprintCollagePrinter.h"
#import "BPPPhotoStore.h"

@implementation BPPAirprintCollagePrinter


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
        self.longsidePixels = CollageLongsidePixels;
        self.shortsidePixels = CollageShortsidePixels;
    }
    return self;
}

// public
// creates collages of up to 6 images in a single image
- (bool)printCollage:(NSArray*)images fromCGRect:(CGRect)rect fromUIView:(UIView*)view successBlock:(printSuccessBlock)successBlock failBlock:(printFailBlock)failBlock {
    
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
            if( successBlock )
                successBlock();

        } else {
            if( error ) {
                NSLog(@"printCollage: printing FAILED! due to error in domain %@ with error code %d", error.domain, (int)error.code);
                failBlock(error);
            } else {
                NSLog(@"printCollage: printing cancelled by user");
            // TODO: UI confirmation of cancel here?
            }
        }
    };
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        [controller presentFromRect:rect inView:view animated:YES completionHandler:completionHandler];
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
            NSLog(@"AirprintCollagePrinter: Made FINAL collage %lu, size is %u", (unsigned long)groupedCollages.count, images.count-imagesConsumed);
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
            NSLog(@"AirprintCollagePrinter: Made collage %lu, size is %d", (unsigned long)groupedCollages.count, batchSize);
            imagesConsumed += batchSize;
        }
    }
    
    NSLog(@"makeCollageUIImageGroupings: returning %lu groups", (unsigned long)groupedCollages.count);
    return groupedCollages;
}

// public
- (NSArray*)makeCollageImages:(NSArray*)collages {
    // default size is full 300dpi size
    return [self makeCollageImages:collages longsideLength:CollageLongsidePixels shortsideLength:CollageShortsidePixels completionBlock:nil];
}

- (NSArray*)makeCollageImages:(NSArray*)collages longsideLength:(CGFloat)longsideLength shortsideLength:(CGFloat)shortsideLength completionBlock:(MakeCollageCompletionBlock)completionBlock {
    
    if( completionBlock != nil ) {
        NSLog(@"PERF DEBUG: makeCollageImages ASYNC START w/%lu set of images, longsideLength %f, short %f", (unsigned long)collages.count, longsideLength, shortsideLength);

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            NSArray *retval = [self makeCollageImagesWork:collages longsideLength:longsideLength shortsideLength:shortsideLength];
            NSAssert(retval.count >= 1, @"COULD NOT MAKE COLLAGES in makeCollageImagesWork");
            completionBlock(retval);
        });
        
        return nil;
    } else {
        NSLog(@"PERF DEBUG: makeCollageImages SYNC START w/%lu images, longsideLength %f, short %f", (unsigned long)collages.count, longsideLength, shortsideLength);

        return [self makeCollageImagesWork:collages longsideLength:longsideLength shortsideLength:shortsideLength];
    }
}

- (NSArray*)makeCollageImagesWork:(NSArray*)collages longsideLength:(CGFloat)longsideLength shortsideLength:(CGFloat)shortsideLength {

    // not sure it needs to be synchronized...
    @synchronized(_printerIDs) {
        
        NSMutableArray *retval = [NSMutableArray array];
        
        for (id thisID in collages) {
            
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(longsideLength, shortsideLength), YES, 1.0);
            [[UIColor CollageBorderUIColor] setFill];
            UIRectFill(CGRectMake(0, 0, longsideLength, shortsideLength));
            
            NSArray* imagesOfThisCollage = (NSArray*)thisID;
            
            if( imagesOfThisCollage.count == 2 ) {
                // orientation: landscape
                
                [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[0] rect:CGRectMake(CollageBorderPixels, CollageBorderPixels, (longsideLength - (3*CollageBorderPixels) ) / 2, (shortsideLength - (2*CollageBorderPixels) ) )];
                
                [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[1] rect:CGRectMake((longsideLength/2) + (CollageBorderPixels/2), CollageBorderPixels, (longsideLength - (3*CollageBorderPixels) ) / 2, (shortsideLength - (2*CollageBorderPixels) ) )];
                
            } else if( imagesOfThisCollage.count == 3 ) {
                // all squares
                
                int width1and2 = (longsideLength - (3*CollageBorderPixels) ) / 3;
                int height1and2= (shortsideLength - (3*CollageBorderPixels) )/ 2;
                
                [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[0] rect:CGRectMake(CollageBorderPixels, CollageBorderPixels, width1and2, height1and2) ];
                [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[1] rect:CGRectMake(CollageBorderPixels, 2*CollageBorderPixels + height1and2, width1and2, height1and2) ];
                [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[2] rect:CGRectMake( 2*CollageBorderPixels+width1and2, CollageBorderPixels, longsideLength - (3*CollageBorderPixels) - width1and2, 2*height1and2 + CollageBorderPixels)];
                
            } else if( imagesOfThisCollage.count == 4 ) {
                // orientation: **PORTRAIT**
                
                UIGraphicsEndImageContext();
                UIGraphicsBeginImageContextWithOptions(CGSizeMake(shortsideLength, longsideLength), YES, 1.0);
                [[UIColor CollageBorderUIColor] setFill];
                UIRectFill(CGRectMake(0, 0, shortsideLength, longsideLength));
                
                [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[0] rect:CGRectMake(CollageBorderPixels, CollageBorderPixels, (shortsideLength - 3*CollageBorderPixels) / 2, (longsideLength - 3*CollageBorderPixels) / 2) ];
                [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[1] rect:CGRectMake((shortsideLength/2) + (CollageBorderPixels/2), CollageBorderPixels, (shortsideLength - 3*CollageBorderPixels) / 2, (longsideLength - 3*CollageBorderPixels) / 2) ];
                [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[2] rect:CGRectMake(CollageBorderPixels, (longsideLength/2) + (CollageBorderPixels/2), (shortsideLength - 3*CollageBorderPixels) / 2, (longsideLength - 3*CollageBorderPixels) / 2) ];
                [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[3] rect:CGRectMake((shortsideLength/2) + (CollageBorderPixels/2), (longsideLength/2) + (CollageBorderPixels/2), (shortsideLength - 3*CollageBorderPixels) / 2, (longsideLength - 3*CollageBorderPixels) / 2) ];
                
            } else if( imagesOfThisCollage.count == 5 ) {
                // orientation: **PORTRAIT**
                
                UIGraphicsEndImageContext();
                UIGraphicsBeginImageContextWithOptions(CGSizeMake(shortsideLength, longsideLength), YES, 1.0);
                [[UIColor CollageBorderUIColor] setFill];
                UIRectFill(CGRectMake(0, 0, shortsideLength, longsideLength));
                
                int width13  = (shortsideLength - 3*CollageBorderPixels) / 2;
                int height13 = (longsideLength - 3*CollageBorderPixels) / 2;
                int width245 = width13;
                int height245= (longsideLength - 4*CollageBorderPixels) / 3;
                
                [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[0] rect:CGRectMake(CollageBorderPixels, CollageBorderPixels, width13, height13) ];
                [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[1] rect:CGRectMake( 2*CollageBorderPixels + width13, CollageBorderPixels, width245, height245 ) ];
                [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[2] rect:CGRectMake(CollageBorderPixels, 2*CollageBorderPixels + height13, width13, height13 ) ];
                [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[3] rect:CGRectMake(2*CollageBorderPixels + width13, 2*CollageBorderPixels + height245, width245, height245) ];
                
                [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[4] rect:CGRectMake( 2*CollageBorderPixels + width13, 3*CollageBorderPixels + 2*height245, width245, height245 )];
                
            } else if( imagesOfThisCollage.count == 6 ) {
                // orientation: landscape
                
                int cellWidth = (longsideLength - (4*CollageBorderPixels)) / 3;
                int cellHeight= (shortsideLength- (3*CollageBorderPixels)) / 2;
                
                [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[0] rect:CGRectMake(CollageBorderPixels, CollageBorderPixels, cellWidth, cellHeight) ];
                
                [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[1] rect:CGRectMake(2*CollageBorderPixels + cellWidth, CollageBorderPixels, cellWidth, cellHeight) ];
                
                [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[2] rect:CGRectMake(3*CollageBorderPixels + 2*cellWidth, CollageBorderPixels, cellWidth, cellHeight) ];
                
                [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[3] rect:CGRectMake(CollageBorderPixels, 2*CollageBorderPixels + cellHeight, cellWidth, cellHeight) ];
                
                [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[4] rect:CGRectMake(2*CollageBorderPixels + cellWidth, 2*CollageBorderPixels + cellHeight, cellWidth, cellHeight) ];
                
                [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[5] rect:CGRectMake(3*CollageBorderPixels + 2*cellWidth, 2*CollageBorderPixels + cellHeight, cellWidth, cellHeight) ];
            }
            
            UIImage* collageImage = UIGraphicsGetImageFromCurrentImageContext();
            [retval addObject:collageImage];
            NSLog(@"makeCollageImages: adding collage UIImage");
            UIGraphicsEndImageContext();
            
        } // end for
        
        NSLog(@"PERF DEBUG: makeCollageImages END");
        return retval;
    }
}

- (bool)isResultingCollageLandscape:(NSArray*)images {
    if( images.count == 4 || images.count == 5 )
        return NO;
    return YES;
}


// private
- (void)resizeAndDrawInRect:(UIImage*)image rect:(CGRect)rect {
    NSLog(@"resizeAndDrawInRec: calling resize. Src: w:%f h:%f. Draw target x:%f y:%f w:%f h:%f", image.size.width, image.size.height, rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
    
    UIImage* resizedAndCroppedImage = [self cropImage:image scaledToFillSize:rect.size];
    // TODO: enable tilt?
    resizedAndCroppedImage = [self tiltAndZoomImage:resizedAndCroppedImage];
    
    if( nil == resizedAndCroppedImage ) {
        NSLog(@"Failed to resize image!");
        return;
    }
    
    [resizedAndCroppedImage drawInRect:(rect)];
    
}


// private - adds a random amount of tilt & zoom to make the image more interesting
- (UIImage*)tiltAndZoomImage:(UIImage*)image {
    
    NSInteger tiltAngle = [self getRandomNumberBetween:0 maxNumber:20];
    tiltAngle = tiltAngle - 10;
    NSInteger extraZoom = [self getRandomNumberBetween:0 maxNumber:20];
    extraZoom = 1 + (extraZoom/100);
    NSLog(@"Tilting with angle %ld", (long)tiltAngle);
    
    UIImage* processedImage = [self imageRotatedByRadians:image angle:tiltAngle];

    return processedImage;
}

- (UIImage *)imageRotatedByRadians:(UIImage*)image angle:(CGFloat)angle
{
    CGFloat radians = angle * (M_PI / 180);

    // calculate the size of the rotated view's containing box for our drawing space
    UIView *rotatedViewBox = [[UIView alloc] initWithFrame:CGRectMake(0,0,image.size.width, image.size.height)];
    CGAffineTransform t = CGAffineTransformMakeRotation(radians);
    rotatedViewBox.transform = t;
    CGSize rotatedSize = rotatedViewBox.frame.size;
    
    // Create the bitmap context
    UIGraphicsBeginImageContext(rotatedSize);
    CGContextRef bitmap = UIGraphicsGetCurrentContext();
    
    // Move the origin to the middle of the image so we will rotate and scale around the center.
    CGContextTranslateCTM(bitmap, rotatedSize.width/2, rotatedSize.height/2);
    
    //Rotate the image context
    CGContextRotateCTM(bitmap, radians);
    
    // Now, draw the rotated/scaled image into the context
//    CGContextScaleCTM(bitmap, 1.0, -1.0);
    CGFloat scaleFactor = angle;
    if( scaleFactor < 0)
        scaleFactor *= -1;
    CGContextScaleCTM(bitmap, 1 + (scaleFactor/18), (1 + (scaleFactor/18)) * -1);
    
    CGContextDrawImage(bitmap, CGRectMake(-image.size.width / 2, -image.size.height / 2, image.size.width, image.size.height), [image CGImage]);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}


- (UIImage *)cropImage:(UIImage *)image scaledToFillSize:(CGSize)size
{
    // do not upscale
    if( image.size.width <= size.width && image.size.height <= size.height )
        return image;
    
    CGFloat scale = MAX(size.width/image.size.width, size.height/image.size.height);
    CGFloat width = image.size.width * scale;
    CGFloat height = image.size.height * scale;
    CGRect imageRect = CGRectMake((size.width - width)/2.0f,
                                  (size.height - height)/2.0f,
                                  width,
                                  height);
    
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    [image drawInRect:imageRect];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

- (UIImage *)fitImage:(UIImage *)image scaledToFillSize:(CGSize)size {
    // do not upscale
    if( image.size.width <= size.width && image.size.height <= size.height )
        return image;
    
    CGFloat scale = MIN(size.width/image.size.width, size.height/image.size.height);
    CGFloat width = image.size.width * scale;
    CGFloat height = image.size.height * scale;
    CGRect imageRect = CGRectMake(0,
                                  0,
                                  width,
                                  height);
    
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
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
