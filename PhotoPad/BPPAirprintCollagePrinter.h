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

typedef void(^MakeCollageCompletionBlock)(NSArray* collageImages);
typedef void(^printSuccessBlock)(void);
typedef void(^printFailBlock)(NSError* error);


@interface BPPAirprintCollagePrinter : NSObject {
    int _lastUsedPrinterIDArrayIndex;
}

+ (BPPAirprintCollagePrinter *)singleton;              // Call this to get the class

// takes an array of UIImage to print. The UIBarButton is where the UI for printing will be rendered near
- (bool)printCollage:(NSArray*)images fromCGRect:(CGRect)rect fromUIView:(UIView*)view successBlock:(printSuccessBlock)successBlock failBlock:(printFailBlock)failBlock;

// input collages is an array of arrays of UIImage*
// output is array of UIImage*, resized to #define'd sizes
- (NSArray*)makeCollageImages:(NSArray*)collages;

// input collages is an array of arrays of UIImage*
// output is array of UIImage*, resized to given sizes
// an NSArray is only returned, if completionBlock is nil; otherwise you get the result in the completionBlock instead
- (NSArray*)makeCollageImages:(NSArray*)collages longsideLength:(CGFloat)longsideLength shortsideLength:(CGFloat)shortsideLength completionBlock:(MakeCollageCompletionBlock)completionBlock;

// input is an array of UIImage
- (bool)isResultingCollageLandscape:(NSArray*)images;

// some utility functions for other classes
// resize images
- (UIImage *)cropImage:(UIImage *)image scaledToFillSize:(CGSize)size;
- (UIImage *)fitImage:(UIImage *)image scaledToFillSize:(CGSize)size;



@property NSMutableArray* printerIDs; // array of strings
@property NSInteger longsidePixels; // used when other classes are preparing images for this class
@property NSInteger shortsidePixels;

@end
