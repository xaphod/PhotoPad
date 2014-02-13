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
#define CollageBorderPixels 10
#define CollageBorderUIColor whiteColor
#define CollageJPGQuality 60.0


@interface BPPAirprintCollagePrinter : NSObject {
    
    
}

+ (BPPAirprintCollagePrinter *)singleton;              // Call this to get the class

// takes an array of UIImage to print
- (NSData*)printCollage:(NSArray*)images;

@end
