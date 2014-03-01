//
//  BPPAirprintCollagePrinter.h
//  PhotoPad
//
//  Created by Tim Carr on 2/9/14.
//  Copyright (c) 2014 Tim Carr. All rights reserved.
//

#import <Foundation/Foundation.h>

// Must be in 4 x 6" ratio - numbers here are for  300DPI.
#define CollageLongsidePixels 1800
#define CollageShortsidePixels 1200
#define CollageBorderPixels 20
#define CollageBorderUIColor whiteColor
#define CollageJPGQuality 0.6 // from 0 to 1, 1 is best quality

#define DEG2RAD(X) ((X)*M_PI/180)

@interface BPPAirprintCollagePrinter : NSObject {
    int _lastUsedPrinterIDArrayIndex;
}

+ (BPPAirprintCollagePrinter *)singleton;              // Call this to get the class

// takes an array of UIImage to print. The UIBarButton is where the UI for printing will be rendered near
- (bool)printCollage:(NSArray*)images  fromUIBarButton:(UIBarButtonItem*)fromUIBarButton;

// input collages is an array of arrays of UIImage*
// output is array of UIImage*
- (NSArray*)makeCollageImages:(NSArray*)collages;

// some utility functions for other classes
// resize images
- (UIImage *)cropImage:(UIImage *)image scaledToFillSize:(CGSize)size;
- (UIImage *)fitImage:(UIImage *)image scaledToFillSize:(CGSize)size;



@property NSMutableArray* printerIDs; // array of strings
@property NSInteger longsidePixels; // used when other classes are preparing images for this class
@property NSInteger shortsidePixels;

@end
