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
// test printing portrait collages - do they auto-rotate?
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
        // init code here
    }
    return self;
}

// public
// creates collages of up to 6 images in a single image
- (NSData*)printCollage:(NSArray*)images {
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
    NSArray *collagesReadyToPrintInNSDataJPG = [self makeCollageJPGs:collageGroupings];
    
    // DEBUG: return just the first jpgdata collage
    return collagesReadyToPrintInNSDataJPG[0];
        
    //UIPrintInteractionController *pic = [UIPrintInteractionController sharedPrintController];
    // print using .printingItem --> takes UIImage
    
 
    //return YES;
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

- (NSArray*)makeCollageJPGs:(NSArray*)collages {
    
    NSMutableArray *collagesReadyToPrintInNSDataJPG = [NSMutableArray array];
    
    for (id thisID in collages) {
        
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(CollageLongsidePixels, CollageShortsidePixels), YES, 1.0);
        [[UIColor CollageBorderUIColor] setFill];
        UIRectFill(CGRectMake(0, 0, CollageLongsidePixels, CollageShortsidePixels));
        
        NSArray* imagesOfThisCollage = (NSArray*)thisID;
        
        if( imagesOfThisCollage.count == 2 ) {
            // orientation: landscape
            // image dimensions for each image:
            //      width = (CollageLongsidePixels - (3*CollageBorderPixels) ) / 2
            //      height= (CollageShortsidePixels - (2*CollageBorderPixels) )
            // image positioning, from top-left of orientation:
            //      1. x=CollageBorderPixels, y=CollageBorderPixels
            //      2. x= (CollageLongsidePixels/2) + (CollageBorderPixels/2), y=CollageBorderPixels
            
            // CGRECTMAKE:  X, Y, WIDTH, HEIGHT
            // [(UIImage*)imagesOfThisCollage[x] drawInRect:(CGRectMake(  ))];
            
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[0] rect:CGRectMake(CollageBorderPixels, CollageBorderPixels, (CollageLongsidePixels - (3*CollageBorderPixels) ) / 2, (CollageShortsidePixels - (2*CollageBorderPixels) ) )];
            
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[1] rect:CGRectMake((CollageLongsidePixels/2) + (CollageBorderPixels/2), CollageBorderPixels, (CollageLongsidePixels - (3*CollageBorderPixels) ) / 2, (CollageShortsidePixels - (2*CollageBorderPixels) ) )];
            
        } else if( imagesOfThisCollage.count == 3 ) {
            // NEW - all squares
           
            int width1and2 = (CollageLongsidePixels - (3*CollageBorderPixels) ) / 3;
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[0] rect:CGRectMake(CollageBorderPixels, CollageBorderPixels, width1and2, (CollageShortsidePixels - (3*CollageBorderPixels) )/ 2 )];
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[1] rect:CGRectMake(CollageBorderPixels, (CollageShortsidePixels/2) + (CollageBorderPixels/2), width1and2, (CollageShortsidePixels - (3*CollageBorderPixels) )/ 2 )];
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[2] rect:CGRectMake( 2*CollageBorderPixels+width1and2, CollageBorderPixels, (CollageLongsidePixels - (3*CollageBorderPixels) )*2/3, CollageShortsidePixels - (2*CollageBorderPixels))];
            
        } else if( imagesOfThisCollage.count == 4 ) {
            // orientation: **PORTRAIT**
            // image dimensions for each image:
            //      width = (CollageShortsidePixels - 3*CollageBorderPixels) / 2
            //      height= (CollageLongsidePixels - 3*CollageBorderPixels) / 2
            // image positioning, from top-left of orientation:
            //      1. x= CollageBorderPixels, y= CollageBorderPixels
            //      2. x= (CollageShortsidePixels/2) + (CollageBorderPixels/2), y= CollageBorderPixels
            //      3. x= CollageBorderPixels, y= (CollageLongsidePixels/2) + (CollageBorderPixels/2)
            //      4. x= (CollageShortsidePixels/2) + (CollageBorderPixels/2), y= (CollageLongsidePixels/2) + (CollageBorderPixels/2)
            
            // portrait - just start a new context
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
            // Images 1 and 3:
            //      width = (CollageShortsidePixels/2) - CollageBorderPixels - (CollageBorderPixels/2)
            //      height= (CollageLongsidePixels/2) - CollageBorderPixels - (CollageBorderPixels/2)
            // Images 2, 4, and 5:
            //      width = (CollageShortsidePixels/2) - CollageBorderPixels - (CollageBorderPixels/2)
            //      height= (CollageLongsidePixels - (4*CollageBorderPixels) )/3
            // image positioning, from top-left of orientation:
            //      1. x= CollageBorderPixels, y= CollageBorderPixels
            //      2. x= (CollageShortsidePixels/2) + (CollageBorderPixels/2), y=CollageBorderPixels
            //      3. x= CollageBorderPixels, y= (CollageLongsidePixels/2) + (CollageBorderPixels/2)
            //      4. x= (CollageShortsidePixels/2) + (CollageBorderPixels/2), y= (CollageLongsidePixels/3) + (CollageBorderPixels/2)
            //      5. x= (CollageShortsidePixels/2) + (CollageBorderPixels/2), y= (CollageLongsidePixels*(2/3)) + (CollageBorderPixels/2)
            
            // portrait - just start a new context
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
            // image dimensions for each image:
            //      width = (CollageLongsidePixels - (4*CollageBorderPixels)) / 3
            //      height= (CollageShortsidePixels- (3*CollageBorderPixels)) / 2
            // image positioning, from top-left of orientation:
            //      1. x= CollageBorderPixels, y= CollageBorderPixels
            //      2. x= (CollageLongsidePixels/3) + (CollageBorderPixels/2), y=CollageBorderPixels
            //      3. x= (CollageLongsidePixels*(2/3)) + (CollageBorderPixels/2), y=CollageBorderPixels
            //      4. x= CollageBorderPixels, y= (CollageShortsidePixels/2) + (CollageBorderPixels/2)
            //      5. x= (CollageLongsidePixels/3) + (CollageBorderPixels/2), y= (CollageShortsidePixels/2) + (CollageBorderPixels/2)
            //      6. x= (CollageLongsidePixels*(2/3)) + (CollageBorderPixels/2), y= (CollageShortsidePixels/2) + (CollageBorderPixels/2)
            
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[0] rect:CGRectMake(CollageBorderPixels, CollageBorderPixels, (CollageLongsidePixels - (4*CollageBorderPixels)) / 3, (CollageShortsidePixels- (3*CollageBorderPixels)) / 2) ];
            
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[1] rect:CGRectMake((CollageLongsidePixels/3) + (CollageBorderPixels/2), CollageBorderPixels, (CollageLongsidePixels - (4*CollageBorderPixels)) / 3, (CollageShortsidePixels- (3*CollageBorderPixels)) / 2) ];
            
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[2] rect:CGRectMake((CollageLongsidePixels*2/3) + (CollageBorderPixels/2), CollageBorderPixels, (CollageLongsidePixels - (4*CollageBorderPixels)) / 3, (CollageShortsidePixels- (3*CollageBorderPixels)) / 2) ];
            
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[3] rect:CGRectMake(CollageBorderPixels, (CollageShortsidePixels/2) + (CollageBorderPixels/2), (CollageLongsidePixels - (4*CollageBorderPixels)) / 3, (CollageShortsidePixels- (3*CollageBorderPixels)) / 2) ];
            
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[4] rect:CGRectMake((CollageLongsidePixels/3) + (CollageBorderPixels/2), (CollageShortsidePixels/2) + (CollageBorderPixels/2), (CollageLongsidePixels - (4*CollageBorderPixels)) / 3, (CollageShortsidePixels- (3*CollageBorderPixels)) / 2) ];
            
            [self resizeAndDrawInRect:(UIImage*)imagesOfThisCollage[5] rect:CGRectMake((CollageLongsidePixels*2/3) + (CollageBorderPixels/2), (CollageShortsidePixels/2) + (CollageBorderPixels/2), (CollageLongsidePixels - (4*CollageBorderPixels)) / 3, (CollageShortsidePixels- (3*CollageBorderPixels)) / 2) ];
        }
        
        NSData* collageJpg = UIImageJPEGRepresentation( UIGraphicsGetImageFromCurrentImageContext(), CollageJPGQuality);
        [collagesReadyToPrintInNSDataJPG addObject:collageJpg];
        UIGraphicsEndImageContext();
    } // end for
    
    return collagesReadyToPrintInNSDataJPG;
}

- (void)resizeAndDrawInRect:(UIImage*)image rect:(CGRect)rect {
    NSLog(@"resizeAndDrawInRec: calling resize. Src: w:%f h:%f. Draw target x:%f y:%f w:%f h:%f", image.size.width, image.size.height, rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
    UIImage* resizedAndCroppedImage = [self resizeAndCropUIImage:image targetWidth:rect.size.width targetHeight:rect.size.height];
    if( nil == resizedAndCroppedImage ) {
        NSLog(@"Failed to resize image!");
        return;
    }
    [resizedAndCroppedImage drawInRect:(rect)];
}


// operates on the UIImage given, returns false if something didn't work
- (UIImage*)resizeAndCropUIImage:(UIImage*)image targetWidth:(double)targetWidth targetHeight:(double)targetHeight {
    // assume the image is already in the correct orientation
    // goal: resize the image but keep the perspective the same, via crop
    
    // only downsize
    if( targetWidth >= image.size.width || targetHeight >= image.size.height )
        return nil;
    
    UIGraphicsPushContext( UIGraphicsGetCurrentContext() );
    
    bool resizeAlongWidth = image.size.width-targetWidth < image.size.height-targetHeight;
    double widthBeforeCrop, heightBeforeCrop, yBeforeCrop, xBeforeCrop; // these are intermediate sizes & pos -- then one of the dimensions is cropped -- in the center
    if( resizeAlongWidth ) {
        NSLog(@"resizeAndCropUIImage: resizing along WIDTH");
        widthBeforeCrop = targetWidth;
        heightBeforeCrop = image.size.height / (image.size.width / targetWidth);
    } else {
        NSLog(@"resizeAndCropUIImage: resizing along HEIGHT");
        widthBeforeCrop = image.size.width / (image.size.height / targetHeight);
        heightBeforeCrop = targetHeight;
    }
    //NSLog(@"resizeAndCropUImage, creating resized image w:%f h:%f", widthBeforeCrop, heightBeforeCrop);

    // resize image before we crop it
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(widthBeforeCrop, heightBeforeCrop), YES, 1.0);
    [image drawInRect:CGRectMake(0, 0, widthBeforeCrop, heightBeforeCrop)];
    UIImage* resultImage = UIGraphicsGetImageFromCurrentImageContext(); // overwrites parameter input
    UIGraphicsEndImageContext();
    
    if( resizeAlongWidth ) {
        yBeforeCrop = (heightBeforeCrop - targetHeight) / 2;
        xBeforeCrop = 0;
    } else {
        yBeforeCrop = 0;
        xBeforeCrop = (widthBeforeCrop - targetWidth) / 2;
    }

    //NSLog(@"resizeAndCropUIImage, creating cropped final image into target. Crop: x:%f y:%f w:%f h:%f", xBeforeCrop, yBeforeCrop, targetWidth, targetHeight);

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(targetWidth, targetHeight), YES, 1.0);
    [[UIColor redColor] setFill]; // shouldn't see the red!
    UIRectFill(CGRectMake(0, 0, targetWidth, targetHeight));
    [resultImage drawAtPoint:CGPointMake(-xBeforeCrop, -yBeforeCrop)];
    resultImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    UIGraphicsPopContext();
    return resultImage;
}

- (NSInteger)getRandomNumberBetween:(NSInteger)min maxNumber:(NSInteger)max
{
    // we don't care about modulo bias
    return min + arc4random() % (max - min + 1);
}

@end
