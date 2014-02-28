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


@interface BPPPhotoStore : NSObject



+ (BPPPhotoStore *)singleton;              // Call this to get the class

- (void)loadFromFileAndDelete:(NSString*)filename completionBlock:(void(^)(void))completionBlock;   // load into photo-store from file, and delete it

- (void)deletePhoto:(NSString*)url;

// returns UIImage* if there is already a resized image in the cache, otherwise executes completionBlock when it is ready
- (UIImage*)getResizedImage:(NSString*)url size:(CGSize)size completionBlock:(void (^)(UIImage* resizedImage))completionBlock;

// can take a while to load from camera roll?
- (UIImage*)getFullsizeImage:(NSString*)url completionBlock:(void (^)(UIImage* fullsizeImage))completionBlock;

// UI-related
- (void)viewControllerIsRotating;
- (void)setReloadTarget:(UICollectionView*)vc;
- (void)flushFullsizeCache;


// TODO: delete if populateAllCachesSynchronous is deleted
@property CGSize targetResizeCGSize;

@property (nonatomic) NSMutableArray* photoURLs; // array of NSString*, repesenting the photos in camera roll -- URLs are ALAssetRepresentation URLs (camera roll)


@end
