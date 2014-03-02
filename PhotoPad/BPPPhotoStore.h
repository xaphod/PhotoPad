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

// these immediately return UIImage* if there is already a resized image in the cache, otherwise executes completionBlock when it is ready (async). The resolution (half, quarter etc) is relative to what BPPAirprintCollagePrinter defines, not the resolution of the input image.
// caller is expected to manage what thread its completionBlock runs on, ie. if UI is calling, UI should dispatch completionblock on main thread
- (UIImage*)getHalfResolutionImage:(NSString*)url completionBlock:(ImageResizeCompletionBlock)completionBlock;
- (UIImage*)getQuarterResolutionImage:(UIImage*)halfResImage url:(NSString*)url;
- (UIImage*)getCellsizeImage:(NSString*)url size:(CGSize)size completionBlock:(ImageResizeCompletionBlock)completionBlock; // performant only when this is called with the same CGSize all the time
    
- (void)didReceiveMemoryWarning;

// UI-related
- (void)viewControllerIsRotating;
- (void)setReloadTarget:(UICollectionView*)vc;


@property (nonatomic) NSMutableArray* photoURLs; // array of NSString*, repesenting the photos in camera roll -- URLs are ALAssetRepresentation URLs (camera roll)


@end
