//
//  BPPPhotoStore.m
//  PhotoPad
//
//  Created by Tim Carr on 2/26/14.
//  Copyright (c) 2014 Tim Carr. All rights reserved.
//

#import "BPPPhotoStore.h"
#import "ALAssetsLibrary+CustomPhotoAlbum.h"
#import "NSFileManager+EyeFi.h"
#import "BPPAirprintCollagePrinter.h"

@interface BPPPhotoStore() {
    ALAssetsLibrary* _photoLibrary;
    NSOperationQueue* _resizedImageCacheOperationQueue;
    NSCache* _resizedImageCache;
    NSCache* _fullsizedImageCache;
    UICollectionView* _vc;
}

@end


@implementation BPPPhotoStore


+ (BPPPhotoStore *)singleton {
    static dispatch_once_t pred;
    static BPPPhotoStore *shared = nil;
    
    dispatch_once(&pred, ^{
        shared = [[BPPPhotoStore alloc] init];
    });
    return shared;
}

- (id)init {
    if (self = [super init]) {
        _photoURLs = [NSMutableArray array];

        _resizedImageCache = [[NSCache alloc] init];
        _fullsizedImageCache = [[NSCache alloc] init];
        _resizedImageCacheOperationQueue = [[NSOperationQueue alloc] init];
        _resizedImageCacheOperationQueue.maxConcurrentOperationCount = 3;
        self.targetResizeCGSize = CGSizeMake(-1.0, -1.0);
        
        // get access to photo roll
        _photoLibrary = [[ALAssetsLibrary alloc] init];
        ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
        
        if (status == ALAuthorizationStatusDenied || status == ALAuthorizationStatusRestricted ) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Need Access to Photos" message:@"Please give this app permission to access your photo library in your settings app." delegate:nil cancelButtonTitle:@"Close" otherButtonTitles:nil, nil];
            [alert show];
        }
        
        // load photos from camera roll
        
        [_photoLibrary getAllImagesFromAlbum:cameraRollAlbumName delegate:self selectorAddImage:@selector(intialLoadPhotoFromCameraRoll:) selectorFinished:@selector(initialLoadIsFinished) withCompletionBlock:^(NSError *error) {
            if (error!=nil) {
                NSLog(@"BPPPhotoStore, init: error loading photos from album %@", [error description]);
            }
        }];

    }

    return self;
}

- (void)setReloadTarget:(UICollectionView*)vc {
    NSLog(@"BPPPhotoStore: reloadTarget set.");
    _vc = vc;
}


- (void)initialLoadIsFinished {
    NSLog(@"BPPPhotoStore: initialLoadIsFinished, calling reloadTarget->reloadData");
    if( _vc )
        dispatch_async(dispatch_get_main_queue(), ^{
            [_vc reloadData];
        });

}

// returns UIImage* if there is already a resized image in the cache, otherwise executes completionBlock when it is ready
- (UIImage*)getResizedImage:(NSString*)url size:(CGSize)size completionBlock:(void (^)(UIImage* resizedImage))completionBlock {
    
    UIImage* cachedImage = [_resizedImageCache objectForKey:url];
    
    if( cachedImage != nil ) {
        return cachedImage;
    } else {
        
        [_resizedImageCacheOperationQueue addOperationWithBlock: ^ {
            
            // TODO: turn on fullsize image caching for all (here) ?
            UIImage* img = [self getFullsizeImageSynchronous:url doCacheImage:NO];
            img = [[BPPAirprintCollagePrinter singleton] cropImage:img scaledToFillSize:size];
            [_resizedImageCache setObject:img forKey:url];

            completionBlock(img);
        }];
    }
    
    return nil;
}

// public.
- (UIImage*)getFullsizeImage:(NSString*)url completionBlock:(void (^)(UIImage* fullsizeImage))completionBlock {
    NSLog(@"BPPPhotoStore: getFullSizeImage for %@", url);
 
    UIImage* cachedImage = [_fullsizedImageCache objectForKey:url];
    if( cachedImage != nil )
        return cachedImage;
    
    [_photoLibrary assetForURL:[NSURL URLWithString:url] resultBlock:^(ALAsset *asset) {
        ALAssetRepresentation* thisImageRep = asset.defaultRepresentation;
        UIImage* thisImageUIImg = [UIImage imageWithCGImage:thisImageRep.fullResolutionImage scale:thisImageRep.scale orientation:(UIImageOrientation)thisImageRep.orientation];

        completionBlock(thisImageUIImg);
    } failureBlock:^(NSError *error) {
        NSAssert(FALSE, @"PhotoStore getFullsizeImage: ERROR, %@", error.localizedDescription);
    }];
    
    return nil;
}


// Private. it's ok if this takes a long time - expectation is that caller puts this in a queue
- (UIImage*)getFullsizeImageSynchronous:(NSString*)url doCacheImage:(bool)doCacheImage {
    
    NSAssert([NSThread currentThread] != [NSThread mainThread], @"THREADING ERROR: don't call getFullsizeImageSynchronous on mainthread, as it has a semaphore block");
    
    UIImage* cachedImage = [_fullsizedImageCache objectForKey:url];
    if( cachedImage != nil )
        return cachedImage;
    
    __block UIImage* retval;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [_photoLibrary assetForURL:[NSURL URLWithString:url] resultBlock:^(ALAsset *asset) {
        ALAssetRepresentation* thisImageRep = asset.defaultRepresentation;
        UIImage* thisImageUIImg = [UIImage imageWithCGImage:thisImageRep.fullResolutionImage scale:thisImageRep.scale orientation:(UIImageOrientation)thisImageRep.orientation];
        retval = thisImageUIImg;
        
        dispatch_semaphore_signal(semaphore);
        
    } failureBlock:^(NSError *error) {
        NSAssert(FALSE, @"PhotoStore getFullsizeImageSnychronous: ERROR, %@", error.localizedDescription);
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    NSLog(@"PhotoStore getFullsizeImageSnychronous: waiting on semaphore, thread %@...", [NSThread currentThread]);
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSLog(@"PhotoStore getFullsizeImageSnychronous: ... done");

    if( doCacheImage ) {
        [_fullsizedImageCache setObject:retval forKey:url];
        NSLog(@"getFullsizeImageSynchronous: cached image.");
    }
    
    return retval;
}


// TODO: delete method?
/*
- (void)populateAllCachesSynchronous:(UIImage*)fullsizeImage cacheKey:(NSString*)cacheKey {
    
    NSAssert(self.targetResizeCGSize.height != -1.0, @"populateAllCaches - make sure you first set targetResizeCGSize");
    
    // approach: use an NSCache, with an NSOperationQueue that limits the number of concurrent ops to 3.
    if( [_fullsizedImageCache objectForKey:cacheKey] == nil ) {
        NSLog(@"populateAllCaches: adding fullsize image to cache, key - %@", cacheKey);
        [_fullsizedImageCache setObject:fullsizeImage forKey:cacheKey];
    }

    if( [_resizedImageCache objectForKey:cacheKey] == nil ) {

        [_resizedImageCacheOperationQueue addOperationWithBlock: ^ {
            UIImage* resizeImg = [self cropImage:fullsizeImage scaledToFillSize:self.targetResizeCGSize];
            [_resizedImageCache setObject:resizeImg forKey:cacheKey];
        }];
    }
}
 */

// called MULTIPLE TIMES from ALAssetsLibrary+Custom
- (void)intialLoadPhotoFromCameraRoll:(NSDictionary*)dict {
    NSString* url = [[dict objectForKey:defImageURLKey] absoluteString];
    if( nil == url ) {
        NSAssert(FALSE, @"nilurl in initialLoadPhotosFromCameraRoll");
        return;
    }
    [_photoURLs addObject:url];
    NSLog(@"loadPhotoFromCameraRoll: added URL to array - %@", url);
    
    UIImage* fullsizeImage = [dict objectForKey:defImageKey];
    if( nil == fullsizeImage ) {
        NSAssert(FALSE, @"nil fullsizeimage in initialLoadPhotosFromCameraRoll.");
        return;
    }
    
    // do we really need this?
    // [self populateAllCaches:fullsizeImage cacheKey:url];
    
    NSLog(@"intialLoadPhotoFromCameraRoll: Finished loading 1 photo from camera roll...");
}

- (void)loadFromFileAndDelete:(NSString*)filename completionBlock:(void(^)(void))completionBlock {
    
    UIImage* fullSizeImage = [UIImage imageWithContentsOfFile:filename];
    if( nil == fullSizeImage ) {
        NSAssert(FALSE, @"loadFromFileAndDelete: should be able to load this image, but got nil.");
        return;
    }
    
    // TODO: optionally cache fullsize image
    // TODO: optionally precreate resized images and cache them
    
    NSLog(@"BPPPhotoStore, loadFromFileandDelete: loaded image from disk.");
    [_photoLibrary saveImage:fullSizeImage toAlbum:cameraRollAlbumName withCompletionBlock:^(NSError *error) {
        
        if( error ) {
            NSLog(@"loadFromFileAndDelete: error in _photoLibrary->saveImage/completionBlock, %@", error.localizedDescription);
            NSAssert(FALSE, @"loadFromFileAndDelete: Error saving to photolibrary");
        } else {
            NSAssert(FALSE, @"BPPPhotoStore, loadFromFileandDelete: ERROR, completionBlock (1)");
        }
    } withAddImageCompletionBlock:^(NSURL *assetURL, NSError *error) {

        if( error ) {
            NSLog(@"loadFromFileAndDelete: error in _photoLibrary->saveImage/AddImageCompletionBlock, %@", error.localizedDescription);
            NSAssert(FALSE, @"loadFromFileAndDelete: Error saving to photolibrary");
        }
        
        [_photoURLs addObject:assetURL.absoluteString];
        NSLog(@"loadFromFileAndDelete: added URL %@", assetURL.absoluteString);

        // delete file from disk now that it is in camera roll
        NSFileManager *files = [NSFileManager defaultManager];
        NSError *delError;
        [files removeItemAtPath:filename error:&delError];
        if( delError ) {
            NSLog(@"loadFromFileAndDelete: deleteFile FAILED. error desc %@", delError.localizedDescription);
        } else {
            NSLog(@"loadFromFileAndDelete: deleteFile, deleted %@", filename);
        }
        
        completionBlock();

    }];
    
}

- (void)deletePhoto:(NSString*)url {
    [self.photoURLs removeObject:url];
    [_fullsizedImageCache removeObjectForKey:url];
    [_resizedImageCache removeObjectForKey:url];
    NSLog(@"deletePhoto: deleted URL %@", url);
}

- (void)viewControllerIsRotating {
    // TODO: implement or delete -- invalidate resize caches?
}

- (void)flushFullsizeCache {
    [_fullsizedImageCache removeAllObjects];
    NSLog(@"BPPPhotoStore: cache flushed for fullsize images");
}

@end
