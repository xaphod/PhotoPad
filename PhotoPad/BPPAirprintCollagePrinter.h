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


@interface BPPAirprintCollagePrinter : NSObject {
    int _lastUsedPrinterIDArrayIndex;
}

+ (BPPAirprintCollagePrinter *)singleton;              // Call this to get the class

// takes an array of UIImage to print. The UIBarButton is where the UI for printing will be rendered near
- (bool)printCollage:(NSArray*)images  fromUIBarButton:(UIBarButtonItem*)fromUIBarButton;

@property NSMutableArray* printerIDs; // array of strings

@end
