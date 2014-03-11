//
//  BPPPhotoStore.h
//  PhotoPad
//
//  Created by Tim Carr on 2/26/14.
//  Copyright (c) 2014 Tim Carr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ALAssetsLibrary+CustomPhotoAlbum.h"

// TODO: make this an app setting?
#define cameraRollAlbumName @"PhotoPad"

typedef void(^ImageResizeCompletionBlock)(UIImage* resizedImage);


@interface BPPPhotoStore : NSObject



+ (BPPPhotoStore *)singleton;              // Call this to get the class
+ (BPPPhotoStore *)singletonWithLargestPreviewSize:(CGFloat)longsidePixels shortsidePixels:(CGFloat)shortsidePixels;


- (void)loadFromFileAndDelete:(NSString*)filename completionBlock:(void(^)(void))completionBlock;   // load into photo-store from file, and delete it

- (void)deletePhoto:(NSString*)url;

// these execute completionBlock when the image is ready (async). The resolution (half, quarter etc) is relative to what BPPAirprintCollagePrinter defines, not the resolution of the input image.
// caller is expected to manage what thread its completionBlock runs on, ie. if UI is calling, UI should dispatch completionblock on main thread
- (void)getHalfResolutionImage:(NSString*)url completionBlock:(ImageResizeCompletionBlock)completionBlock;
- (UIImage*)getQuarterResolutionImage:(UIImage*)halfResImage url:(NSString*)url;
- (void)getCellsizeImage:(NSString*)url size:(CGSize)size completionBlock:(ImageResizeCompletionBlock)completionBlock; // performant only when this is called with the same CGSize all the time
    
- (void)didReceiveMemoryWarning;
- (void)cacheClean;

// UI-related
- (void)viewControllerIsRotating;
- (void)registerCallbackAfterCameraRollLoadComplete:(id)delegate selector:(SEL)selector; // if you want photostore to call a method when loading from camera roll is complete, then call this. Callback will be on main thread. Also called when image is detected as missing from camera roll (ie URL removed).

@property (nonatomic) NSMutableArray* photoURLs; // array of NSString*, repesenting the photos in camera roll -- URLs are ALAssetRepresentation URLs (camera roll)


@end
