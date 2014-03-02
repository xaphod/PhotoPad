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


#pragma mark - ImageResizeOperation

@interface ImageResizeOperation: NSOperation

@property (nonatomic, strong) UIImage* sourceImage;
@property (copy) ImageResizeCompletionBlock myCompletionBlock;
@property CGSize size;
@property BOOL crop;

- (id)initWithImage:(UIImage*)image size:(CGSize)size crop:(BOOL)crop resizeFinishCompletionBlock:(ImageResizeCompletionBlock)resizeFinishCompletionBlock;
@end

@implementation ImageResizeOperation
- (void)main {

    @autoreleasepool {

        BPPAirprintCollagePrinter* ap = [BPPAirprintCollagePrinter singleton];
        UIImage* image;
        if( self.crop )
            image = [ap cropImage:self.sourceImage scaledToFillSize:self.size];
        else
            image = [ap fitImage:self.sourceImage scaledToFillSize:self.size];
        

        NSLog(@"ImageResizeOperation complete: new size w %f h %f. Calling CompletionBlock now...", self.size.width, self.size.height);
        if( self.myCompletionBlock )
            self.myCompletionBlock(image);
    }
}

- (id)initWithImage:(UIImage*)image size:(CGSize)size crop:(BOOL)crop resizeFinishCompletionBlock:(ImageResizeCompletionBlock)resizeFinishCompletionBlock {
    self = [super init];
    self.myCompletionBlock = resizeFinishCompletionBlock;
    self.sourceImage = image;
    self.size = size;
    self.crop = crop;
    return self;
}

@end




#pragma mark - Main PhotoStore Implementation

@interface BPPPhotoStore() {
    ALAssetsLibrary* _photoLibrary;

    NSCache* _imageCache_2er; // half of resolution of #define. Original aspect ratio
    NSCache* _imageCache_4er; // quarter resolution of #define. Original aspect ration -- generated when 2er is generated, from 2er
    NSCache* _imageCache_cellsize; // resolution of cellsize. Currently is a square aspect ratio

    NSOperationQueue* _imageCacheQueue; // all operations in same queue, so that the priorities can be relevant to one-another
    
    CGFloat _largestPreviewsize_longsidePixels; // used to figure out the resize target for cached resized images
    CGFloat _largestPreviewsize_shortsidePixels;

    UICollectionView* _vc;
}

@end


@implementation BPPPhotoStore

static dispatch_once_t pred;
static BPPPhotoStore *shared = nil;

+ (BPPPhotoStore *)singletonWithLargestPreviewSize:(CGFloat)longsidePixels shortsidePixels:(CGFloat)shortsidePixels {
    
    dispatch_once(&pred, ^{
        shared = [[BPPPhotoStore alloc] initWithLargestPreviewSize:longsidePixels shortsidePixels:shortsidePixels];
        NSLog(@"BPPPhotoStore generated, long pixels %f, short %f", longsidePixels, shortsidePixels);
    });
    return shared;
}

+ (BPPPhotoStore *)singleton {
    
    dispatch_once(&pred, ^{
        BPPAirprintCollagePrinter *ap = [BPPAirprintCollagePrinter singleton];
        shared = [[BPPPhotoStore alloc] initWithLargestPreviewSize:ap.longsidePixels shortsidePixels:ap.shortsidePixels];
    });
    return shared;
}

- (id)initWithLargestPreviewSize:(CGFloat)longsidePixels shortsidePixels:(CGFloat)shortsidePixels {
    if (self = [super init]) {
        _photoURLs = [NSMutableArray array];
        
        _largestPreviewsize_longsidePixels = longsidePixels;
        _largestPreviewsize_shortsidePixels= shortsidePixels;

        _imageCache_2er = [[NSCache alloc] init];
        [_imageCache_2er setTotalCostLimit:7]; // number of images
        _imageCache_4er = [[NSCache alloc] init];
        [_imageCache_4er setTotalCostLimit:7]; // number of images
        _imageCache_cellsize = [[NSCache alloc] init];
        [_imageCache_cellsize setTotalCostLimit:30];
        _imageCacheQueue = [[NSOperationQueue alloc] init];
        _imageCacheQueue.maxConcurrentOperationCount = 3;
        
        // get access to photo roll
        _photoLibrary = [[ALAssetsLibrary alloc] init];
        ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
        
        if (status == ALAuthorizationStatusDenied || status == ALAuthorizationStatusRestricted ) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Need Access to Photos" message:@"Please give this app permission to access your photo library in your settings app." delegate:nil cancelButtonTitle:@"Close" otherButtonTitles:nil, nil];
            [alert show];
        }
        
        // load photos from camera roll
        
        [_photoLibrary getAllImageURLsFromAlbum:cameraRollAlbumName delegate:self selectorAddImage:@selector(intialLoadPhotoFromCameraRoll:) selectorFinished:@selector(initialLoadIsFinished) withCompletionBlock:^(NSError *error) {
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


// hopefully this is called with the same CGSize all the time
- (UIImage*)getCellsizeImage:(NSString*)url size:(CGSize)size completionBlock:(ImageResizeCompletionBlock)completionBlock {
    
    UIImage* cachedImage = [_imageCache_cellsize objectForKey:url];
    
    if( cachedImage != nil ) {
        if( cachedImage.size.height == size.height && cachedImage.size.width == size.width ) {
            NSLog(@"BPPPhotoStore: getCellsizeImage: cache HIT");
            return cachedImage;
        }
    }
    
    __weak NSCache* imageCache_cellsize = _imageCache_cellsize;
    __weak NSOperationQueue* imageCacheQueue = _imageCacheQueue;
    
    // otherwise, generate a new resized image and populate the cache
    [self loadImageFromCameraRollByURL:url completionBlock:^(UIImage* fullsizeImage) {
        
        ImageResizeOperation* resizeOp = [[ImageResizeOperation alloc] initWithImage:fullsizeImage size:size crop:YES resizeFinishCompletionBlock:^(UIImage* resizedImage) {
            
            // cache it, and call completion block from getCellsizeImage's caller
            NSLog(@"BPPPhotoStore getCellSizeImage: DONE, adding resized image to cache");
            [imageCache_cellsize setObject:resizedImage forKey:url cost:1];
            if( completionBlock )
                completionBlock(resizedImage);
            
            // generate the rest of the cache sized images
//            [self getHalfResolutionImage:url completionBlock:nil];
            // TODO: further perf improvement - somehow pass on the 2er to be used as the 4er's input
//            [self getQuarterResolutionImage:url completionBlock:nil];
            // TODO: just an idea if perf is still a problem: instead of doing cellsize first, do 2er first, then do 4er from 2er, and cellsize from 4er
        }];
        
        // run the operation
        NSLog(@"BPPPhotoStore getCellSizeImage: adding resize op to queue now");
        [imageCacheQueue addOperation:resizeOp];
        
    }];
    
    return nil;
}

- (UIImage*)getHalfResolutionImage:(NSString*)url completionBlock:(ImageResizeCompletionBlock)completionBlock {
    return [self getHalfResolutionImage:url pri:NSOperationQueuePriorityNormal completionBlock:completionBlock];
}

- (UIImage*)getHalfResolutionImage:(NSString*)url pri:(NSOperationQueuePriority)pri completionBlock:(ImageResizeCompletionBlock)completionBlock {
    
    UIImage* cachedImage = [_imageCache_2er objectForKey:url];
    BPPAirprintCollagePrinter *ap = [BPPAirprintCollagePrinter singleton];

    if( cachedImage != nil ) {
        NSLog(@"BPPPhotoStore: getHalfResolutionImage: cache HIT");
        return cachedImage;
    }
    
    __weak NSCache* imageCache_2er = _imageCache_2er;
    __weak NSOperationQueue* imageCacheQueue = _imageCacheQueue;
    
    // otherwise, generate a new resized image and populate the cache
    [self loadImageFromCameraRollByURL:url completionBlock:^(UIImage* fullsizeImage) {
        
        CGSize targetSize;
        if( fullsizeImage.size.width > fullsizeImage.size.height ) {
            targetSize = CGSizeMake(MAX(ap.longsidePixels, _largestPreviewsize_longsidePixels), MAX(ap.shortsidePixels, _largestPreviewsize_shortsidePixels) );
        } else {
            targetSize = CGSizeMake(MAX(ap.shortsidePixels, _largestPreviewsize_shortsidePixels), MAX(ap.longsidePixels, _largestPreviewsize_longsidePixels) );
        }
        
        if( targetSize.height < fullsizeImage.size.height && targetSize.width < fullsizeImage.size.width ) {
            ImageResizeOperation* resizeOp = [[ImageResizeOperation alloc] initWithImage:fullsizeImage size:targetSize crop:NO resizeFinishCompletionBlock:^(UIImage* resizedImage) {
                
                // cache it, and call completion block from caller
                NSLog(@"BPPPhotoStore getHalfResolutionImage: DONE, adding resized image to cache. w: %f  h: %f", targetSize.width, targetSize.height);
                [imageCache_2er setObject:resizedImage forKey:url cost:1];
                
                if( completionBlock )
                    completionBlock(resizedImage);
                
            }];
            // run the operation
            [resizeOp setQueuePriority:pri];
            NSLog(@"BPPPhotoStore getHalfResolutionImage: adding resize op to queue now");
            [imageCacheQueue addOperation:resizeOp];
            
        } else {
            NSLog(@"BPPPhotoStore getHalfResolutionImage: not resizing (too small). Current w: %f  h: %f", fullsizeImage.size.width, fullsizeImage.size.height);
            [imageCache_2er setObject:fullsizeImage forKey:url cost:1];
            if( completionBlock )
                completionBlock(fullsizeImage);
        }
        
    }];
    
    return nil;
}

- (UIImage*)getQuarterResolutionImage:(UIImage*)halfResImage url:(NSString*)url {

    UIImage* cachedImage = [_imageCache_4er objectForKey:url];
    if( cachedImage != nil ) {
        NSLog(@"BPPPhotoStore: getQuarterResolutionImage: cache HIT");
        return cachedImage;
    }

    BPPAirprintCollagePrinter *ap = [BPPAirprintCollagePrinter singleton];
    // TODO: this is too dependent upon BPPAirprintCollagePrinter, namely its collage layouts!
    CGSize targetSize;
    
    if( halfResImage.size.width > halfResImage.size.height ) {
        targetSize = CGSizeMake(MAX(ap.longsidePixels/2, _largestPreviewsize_longsidePixels/2), MAX(ap.shortsidePixels/2, _largestPreviewsize_shortsidePixels/2) );
    } else {
        targetSize = CGSizeMake(MAX(ap.shortsidePixels/2, _largestPreviewsize_shortsidePixels/2), MAX(ap.longsidePixels/2, _largestPreviewsize_longsidePixels/2) );
    }
    
    if( targetSize.height < halfResImage.size.height && targetSize.width < halfResImage.size.width ) {
        cachedImage = [ap fitImage:halfResImage scaledToFillSize:targetSize];
        [_imageCache_4er setObject:cachedImage forKey:url cost:1];
        NSLog(@"BPPPhotoStore: getQuarterResolutionImage: generation complete. w: %f  h: %f", targetSize.width, targetSize.height);
    } else {
        NSLog(@"BPPPhotoStore: getQuarterResolutionImage: quarter would be too small, just returning halfres");
        cachedImage = halfResImage;
    }
    return cachedImage;
}


// private: does not load from cache!
- (void)loadImageFromCameraRollByURL:(NSString*)url completionBlock:(void (^)(UIImage* fullsizeImage))completionBlock {
    NSLog(@"BPPPhotoStore: loadImageFromCameraRollByURL for %@", url);
 
    [_photoLibrary assetForURL:[NSURL URLWithString:url] resultBlock:^(ALAsset *asset) {
        ALAssetRepresentation* thisImageRep = asset.defaultRepresentation;
        UIImage* thisImageUIImg = [UIImage imageWithCGImage:thisImageRep.fullResolutionImage scale:thisImageRep.scale orientation:(UIImageOrientation)thisImageRep.orientation];

        if( completionBlock )
            completionBlock(thisImageUIImg);
        
    } failureBlock:^(NSError *error) {
        NSAssert(FALSE, @"BPPPhotoStore loadImageFromCameraRollByURL: ERROR, %@", error.localizedDescription);
    }];
}



// called MULTIPLE TIMES from ALAssetsLibrary+Custom
- (void)intialLoadPhotoFromCameraRoll:(NSURL*)url {

    if( nil == url ) {
        NSAssert(FALSE, @"nilurl in initialLoadPhotosFromCameraRoll");
        return;
    }
    
    if( ! [url isKindOfClass:[NSURL class]] ) {
        NSAssert(FALSE, @"I expect input as NSURL not NSString, in initialLoadPhotosFromCameraRoll");
        return;
    }
    
    [_photoURLs addObject:url.absoluteString];
    NSLog(@"loadPhotoFromCameraRoll: added URL to array - %@", url);
}

- (void)loadFromFileAndDelete:(NSString*)filename completionBlock:(void(^)(void))completionBlock {
    
    UIImage* fullSizeImage = [UIImage imageWithContentsOfFile:filename];
    if( nil == fullSizeImage ) {
        NSAssert(FALSE, @"loadFromFileAndDelete: should be able to load this image, but got nil.");
        return;
    }
    
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
        
        // generate 2er
        [self getHalfResolutionImage:assetURL.absoluteString pri:NSOperationQueuePriorityLow completionBlock:^(UIImage *resizedImage) {
            NSLog(@"loadFromFileAndDelete: generated 2er cache resize");
        }];
        
        if( completionBlock )
            completionBlock();
    }];
    
}

// TODO: not  safe: there could be queued ops to fill the caches while the image itself is deleted
- (void)deletePhoto:(NSString*)url {
    [self.photoURLs removeObject:url];
    [_imageCache_2er removeObjectForKey:url];
    [_imageCache_4er removeObjectForKey:url];
    [_imageCache_cellsize removeObjectForKey:url];
    NSLog(@"deletePhoto: deleted URL %@", url);
}

- (void)viewControllerIsRotating {
    // TODO: implement or delete -- invalidate resize caches?
}

- (void)didReceiveMemoryWarning {
    [_imageCache_2er removeAllObjects];
    [_imageCache_4er removeAllObjects];
    [_imageCache_cellsize removeAllObjects];
}

- (void)cacheClean {
    [_imageCache_2er removeAllObjects];
    [_imageCache_4er removeAllObjects];
}

@end
