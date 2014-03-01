//
//  ALAssetsLibrary category to handle a custom photo album
//
//  Copyright (c) 2014 Tim Carr. All rights reserved.
//  http://www.touch-code-magazine.com/ios5-saving-photos-in-custom-photo-album-category-for-download/
//  Original by Marin Todorov on 10/26/11.

#import "ALAssetsLibrary+CustomPhotoAlbum.h"

@implementation ALAssetsLibrary(CustomPhotoAlbum)

-(void)saveImage:(UIImage*)image toAlbum:(NSString*)albumName withCompletionBlock:(SaveImageCompletion)completionBlock withAddImageCompletionBlock:(AddImageCompletion)addImageCompletionBlock
{

    //write the image data to the assets library (camera roll)
    [self writeImageToSavedPhotosAlbum:image.CGImage orientation:(ALAssetOrientation)image.imageOrientation
                       completionBlock:^(NSURL* assetURL, NSError* error) {
                           
                           //error handling
                           if (error!=nil) {
                               if( completionBlock )
                                   completionBlock(error);
                               return;
                           }
                  
                           //add the asset to the custom photo album
                           [self addAssetURL: assetURL
                                     toAlbum:albumName
                         withCompletionBlock:completionBlock withAddImageCompletionBlock:addImageCompletionBlock];
                           
                       }];
}

-(void)addAssetURL:(NSURL*)assetURL toAlbum:(NSString*)albumName withCompletionBlock:(SaveImageCompletion)completionBlock withAddImageCompletionBlock:(AddImageCompletion)addImageCompletionBlock
{
    __block BOOL albumWasFound = NO;
    
    //search all photo albums in the library
    [self enumerateGroupsWithTypes:ALAssetsGroupAlbum
                        usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
                            
                            //compare the names of the albums
                            if ([albumName compare: [group valueForProperty:ALAssetsGroupPropertyName]]==NSOrderedSame) {

                                //target album is found
                                albumWasFound = YES;
                                
                                //get a hold of the photo's asset instance
                                [self assetForURL: assetURL
                                      resultBlock:^(ALAsset *asset) {
                                          
                                          //add photo to the target album
                                          [group addAsset: asset];
                                          
                                          //run the completion block
                                          if( addImageCompletionBlock )
                                              addImageCompletionBlock(assetURL, nil);
                                          
                                      } failureBlock: completionBlock];
                                
                                //album was found, bail out of the method
                                return;
                            }
                            
                            if (group==nil && albumWasFound==NO) {
                                //photo albums are over, target album does not exist, thus create it
                                
                                __weak ALAssetsLibrary* weakSelf = self;
                                
                                //create new assets album
                                [self addAssetsGroupAlbumWithName:albumName
                                                      resultBlock:^(ALAssetsGroup *group) {
                                                          
                                                          //get the photo's instance
                                                          [weakSelf assetForURL: assetURL
                                                                    resultBlock:^(ALAsset *asset) {
                                                                        
                                                                        //add photo to the newly created album
                                                                        [group addAsset: asset];
                                                                        
                                                                        //call the completion block
                                                                        
                                                                        if( completionBlock )
                                                                            completionBlock(nil);
                                                                        
                                                                    } failureBlock: completionBlock];
                                                          
                                                      } failureBlock: completionBlock];
                                
                                NSLog(@"ALAssetsLib: created album %@", albumName);
                                //should be the last iteration anyway, but just in case
                                return;
                            }
                            
                        } failureBlock: completionBlock];
    
}


- (void)getAllImageURLsFromAlbum:(NSString*)albumName delegate:(id)delegate selectorAddImage:(SEL)selectorAddImage selectorFinished:(SEL)selectorFinished withCompletionBlock:(SaveImageCompletion)completionBlock {
    
    //this *MUST* execute on a background thread, ALAssetLibrary tries to use the main thread and will hang if you're on the main thread.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        //Background Thread

        __block BOOL albumWasFound = NO;
        
        //search all photo albums in the library
        [self enumerateGroupsWithTypes:ALAssetsGroupAlbum
                            usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
                                
                                //compare the names of the albums
                                if ([albumName compare: [group valueForProperty:ALAssetsGroupPropertyName]]==NSOrderedSame) {
                                    
                                    //target album is found
                                    albumWasFound = YES;
                                    
                                    [group enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                                        
                                        if( result != nil ) {
                                            ALAssetRepresentation* thisImageRep = result.defaultRepresentation;
                                            
                                            if( [delegate respondsToSelector:selectorAddImage] )
                                                [delegate performSelector:selectorAddImage withObject:thisImageRep.url];
                                            else
                                                NSLog(@"getAllImagesFromAlbum: Programming error: no response to add-image selector");
                                        }
                                        return;
                                    }];
                                    
                                    if( [delegate respondsToSelector:selectorFinished] )
                                        [delegate performSelector:selectorFinished];
                                    else
                                        NSLog(@"getAllImagesFromAlbum: Programming error: no response to add-image selector");

                                    return;
                                }
                                
                                if (group==nil && albumWasFound==NO) {
                                    if( [delegate respondsToSelector:selectorFinished] )
                                        [delegate performSelector:selectorFinished];
                                    else
                                        NSLog(@"getAllImagesFromAlbum: Programming error: no response to add-image selector");

                                    return;
                                }
                                
                            } failureBlock: completionBlock];
    });
}

@end
