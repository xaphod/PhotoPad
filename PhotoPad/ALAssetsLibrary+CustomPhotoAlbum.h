//
//  ALAssetsLibrary category to handle a custom photo album
//
//  Created by Marin Todorov on 10/26/11.
//  Copyright (c) 2011 Marin Todorov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

#define defImageKey @"UIImageKey"
#define defImageURLKey @"ALAssetRepresentationKey"

typedef void(^SaveImageCompletion)(NSError* error);
typedef void(^AddImageCompletion)(NSURL* assetURL, NSError* error);

@interface ALAssetsLibrary(CustomPhotoAlbum)

-(void)saveImage:(UIImage*)image toAlbum:(NSString*)albumName withCompletionBlock:(SaveImageCompletion)completionBlock withAddImageCompletionBlock:(AddImageCompletion)addImageCompletionBlock;

-(void)addAssetURL:(NSURL*)assetURL toAlbum:(NSString*)albumName withCompletionBlock:(SaveImageCompletion)completionBlock withAddImageCompletionBlock:(AddImageCompletion)addImageCompletionBlock;

// input:  album NSString*
// return: number of images in the album (synchronously)
// result, if album exists: will call delegate->selector once per image found, with an NSDictionary as object: use defImageKey to get the UIImage*, use defImageURLKey to get the URL.
// result, if album doesn't exist: album is created, delegate->selector is not called
- (void)getAllImagesFromAlbum:(NSString*)albumName delegate:(id)delegate selectorAddImage:(SEL)selectorAddImage selectorFinished:(SEL)selectorFinished withCompletionBlock:(SaveImageCompletion)completionBlock;

@end