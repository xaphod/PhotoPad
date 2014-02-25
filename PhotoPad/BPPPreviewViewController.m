//
//  BPPPreviewViewController.m
//  PhotoPad
//
//  Created by Tim Carr on 2/25/14.
//  Copyright (c) 2014 Albert Martin. All rights reserved.
//

#import "BPPPreviewViewController.h"
#import "BPPGalleryCell.h"
#import "NSFileManager+Tar.h"
#import "UIColor+Hex.h"
#import "BPPAirprintCollagePrinter.h"

@interface BPPPreviewViewController () {
    NSOperationQueue* _resizedImageCacheOperationQueue;
    NSCache* _resizedImageCache;
    NSCache* _fullsizedImageCache;
    CGFloat cellSize;
    NSIndexPath* _oldestNewestIndexPath;
    NSNumber* _previewIsShown;
    
    // DEBUG: ReMOVE THIS
    bool debugJPGdone;
}

@end

@implementation BPPPreviewViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    
    [self updateUIFromSettings];
    cellSize = -1;
    _previewIsShown = [NSNumber numberWithBool:FALSE];
	
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(updateUIFromSettings)
                                                name:NSUserDefaultsDidChangeNotification
                                              object:nil];
    
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(addToRightSideOfCollectionView:)
                                                name:@"EyeFiUnarchiveComplete"
                                              object:nil];
    
    _photoFilenames = [NSMutableArray array];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    [_photoFilenames addObjectsFromArray: [[NSBundle bundleWithPath:[paths objectAtIndex:0]] pathsForResourcesOfType:@".JPG" inDirectory:nil]];
    // want to display newest at top
    [_photoFilenames sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    _photoFilenames = [[[_photoFilenames reverseObjectEnumerator] allObjects] mutableCopy];
    
    // Setup the photo browser.
    _photosBrowser = [[MWPhotoBrowser alloc] initWithDelegate:self];
    [_photosBrowser showPreviousPhotoAnimated:YES];
    [_photosBrowser showNextPhotoAnimated:YES];
    
    // Setup a long press to reveal an action menu.
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(activateActionMode:)];
    longPress.delegate = self;
    [_collectionView addGestureRecognizer:longPress];
    self.photoToolSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Delete" otherButtonTitles:nil];
    
    self.collectionView.allowsMultipleSelection = YES;
    self.selectedPhotos = [NSMutableDictionary dictionary];
    
    _resizedImageCache = [[NSCache alloc] init];
    _fullsizedImageCache = [[NSCache alloc] init];
    _resizedImageCacheOperationQueue = [[NSOperationQueue alloc] init];
    _resizedImageCacheOperationQueue.maxConcurrentOperationCount = 3;
    
}

- (void)viewDidAppear:(BOOL)animated
{
    // Show help if the user has not defined a card key.
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"upload_key"]) {
        [self performSegueWithIdentifier:@"showHelp" sender: self];
    }
}

- (UIImage *)imageWithImage:(UIImage *)image scaledToFillSize:(CGSize)size
{
    CGFloat scale = MAX(size.width/image.size.width, size.height/image.size.height);
    CGFloat width = image.size.width * scale;
    CGFloat height = image.size.height * scale;
    CGRect imageRect = CGRectMake((size.width - width)/2.0f,
                                  (size.height - height)/2.0f,
                                  width,
                                  height);
    
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    [image drawInRect:imageRect];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)updateUIFromSettings
{
    NSUserDefaults * standardUserDefaults = [NSUserDefaults standardUserDefaults];
    NSString *windowTitle = [standardUserDefaults objectForKey:@"window_title"];
    NSString *navbarColor = [standardUserDefaults objectForKey:@"window_color"];
    UIColor *navbarTint = [UIColor colorWithHexString: (navbarColor) ?: @"#000000"];
    
    [[UINavigationBar appearance] setBarTintColor: navbarTint];
    [[UIToolbar appearance] setTintColor: [UIColor whiteColor]];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    self.navigationController.navigationBar.barTintColor = navbarTint;
    
    self.navigationController.navigationBar.topItem.title = (windowTitle) ?: @"Browse All Photos";
}

#pragma mark - Photo Gallery

- (void)addToRightSideOfCollectionView:(NSNotification *)notification
{
    NSLog(@"addToRightSideOfCollectionView: START, currentThread %@", [NSThread currentThread]);
    
    NSString* filename = [notification.userInfo objectForKey:@"path"];
    
    int numItemsBeforeInsert = (int)self.photoFilenames.count;
    [self.photoFilenames addObject:filename];
    
    // rest is capable of adding more than one item...
    [UIView setAnimationsEnabled:NO];
    NSMutableArray *arrayWithIndexPaths = [NSMutableArray array];
    for (int i = numItemsBeforeInsert; i < numItemsBeforeInsert + 1; i++)
        [arrayWithIndexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
    
    [self.collectionView performBatchUpdates:^{
        [self.collectionView insertItemsAtIndexPaths:arrayWithIndexPaths];
    } completion:^(BOOL finished) {
        [UIView setAnimationsEnabled:YES];
    }];
    
    if( self.notificationOfNewPhotosViewOutlet.hidden ) {
        if( ! [self.collectionView.indexPathsForVisibleItems containsObject:arrayWithIndexPaths[0]] ) {
            // first item we just added not visible
            _oldestNewestIndexPath = arrayWithIndexPaths[0];
            self.notificationOfNewPhotosViewOutlet.hidden = FALSE;
        }
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"EyeFiCommunication" object:nil userInfo:[NSDictionary dictionaryWithObject:@"GalleryUpdated" forKey:@"method"]];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    NSLog(@"numberOfItemsInSection: returning %d", (int)self.photoFilenames.count);
    return self.photoFilenames.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    BPPGalleryCell *cell = (BPPGalleryCell *)[collectionView dequeueReusableCellWithReuseIdentifier:@"PhotoCell" forIndexPath:indexPath];
    
    // cells don't remember their state
    cell.backgroundColor = [UIColor whiteColor];
    NSString *filename = self.photoFilenames[indexPath.row];
    if( [self.selectedPhotos objectForKey:filename] != nil ) {
        [cell.checkmarkViewOutlet setChecked:YES];
        cell.selected = TRUE;
    } else {
        [cell.checkmarkViewOutlet setChecked:NO];
        cell.selected = FALSE;
    }
    
    // approach: use an NSCache, with an NSOperationQueue that limits the number of concurrent ops to 3.
    UIImage* cachedResizeImg = [_resizedImageCache objectForKey:self.photoFilenames[indexPath.row]];
    
    if( cachedResizeImg ) {
        cell.asset = cachedResizeImg;
    } else {
        CGSize size = CGSizeMake(cellSize, cellSize);
        
        [_resizedImageCacheOperationQueue addOperationWithBlock: ^ {
            
            UIImage *resizeImg = [self loadFullsizeImage:self.photoFilenames[indexPath.row]];
            resizeImg = [self imageWithImage:resizeImg scaledToFillSize:size];
            [_resizedImageCache setObject:resizeImg forKey:self.photoFilenames[indexPath.row]];
            
            if( [_collectionView.indexPathsForVisibleItems containsObject:indexPath] ) {
                // Get hold of main queue (main thread)
                [[NSOperationQueue mainQueue] addOperationWithBlock: ^ {
                    BPPGalleryCell *thisCell = (BPPGalleryCell*)[_collectionView cellForItemAtIndexPath:indexPath];
                    thisCell.asset = resizeImg;
                }];
            }
        }];
    }
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    BPPGalleryCell *cell = (BPPGalleryCell*)[collectionView cellForItemAtIndexPath:indexPath];
    [cell.checkmarkViewOutlet setChecked:YES];
    
    NSString *filename = [self.photoFilenames objectAtIndex:indexPath.row];
    [self.selectedPhotos setObject:[self loadFullsizeImage:filename] forKey:filename];
    [self updatePreview];
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    BPPGalleryCell *cell = (BPPGalleryCell*)[collectionView cellForItemAtIndexPath:indexPath];
    [cell.checkmarkViewOutlet setChecked:NO];
    // TODO: all array ops should be in a function that captures exceptions?
    NSString *filename = [self.photoFilenames objectAtIndex:indexPath.row];
    [self.selectedPhotos removeObjectForKey:filename];
    [self updatePreview];
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    if( cellSize == -1 ) {
        cellSize = self.collectionViewFlowLayoutOutlet.itemSize.height - 2*cellInsets;
        NSLog(@"Set cellSize to %f", cellSize);
    }
    return CGSizeMake(cellSize, cellSize);
}


- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [_resizedImageCache removeAllObjects];
    [self.collectionView.collectionViewLayout invalidateLayout];
}

- (void)activateActionMode:(UILongPressGestureRecognizer *)gr
{
    if (gr.state == UIGestureRecognizerStateBegan) {
        NSIndexPath *indexPath = [_collectionView indexPathForItemAtPoint:[gr locationInView:_collectionView]];
        UICollectionViewLayoutAttributes *cellAtributes = [_collectionView layoutAttributesForItemAtIndexPath:indexPath];
        self.selectedIndex = indexPath.row;
        [self.photoToolSheet showFromRect:cellAtributes.frame inView:_collectionView animated:YES];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0) {
        // Delete button was pressed.
        [[NSFileManager defaultManager] removeItemAtPath:[_photoFilenames objectAtIndex:_selectedIndex] error:nil];
        [_photoFilenames removeObjectAtIndex:_selectedIndex];
        [_collectionView deleteItemsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForItem:_selectedIndex inSection:0]]];
        //        [_collectionView reloadData];
    }
}

- (void)clearCellSelections {
    NSLog(@"clearCellSelections begin");
    
    NSArray* selectedIndexPaths = [self.collectionView indexPathsForSelectedItems];
    
    for( id indexPath in selectedIndexPaths ) {
        [self.collectionView deselectItemAtIndexPath:indexPath animated:YES];
        [self collectionView:self.collectionView didDeselectItemAtIndexPath:indexPath];
    }
}


#pragma mark - Photo Browser

- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser {
    return self.photoFilenames.count;
}

- (MWPhoto *)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
    if (index < self.photoFilenames.count)
        return [MWPhoto photoWithImage:[self loadFullsizeImage:[self.photoFilenames objectAtIndex:index]]];
    return nil;
}

#pragma mark - Printing

- (IBAction)PrintPressed:(id)sender {
    NSLog(@"PrintPressed, %lu photos to print.", (unsigned long)self.selectedPhotos.count);
    
    // TODO: progress indicator -- printCollage takes about 0.5s until it shows iOS print ui
    
    BPPAirprintCollagePrinter *ap = [BPPAirprintCollagePrinter singleton];
    
    if( ! [ap printCollage:[self.selectedPhotos allValues] fromUIBarButton:self.printButtonOulet] ) {
        NSLog(@"MainVC, got fail for printCollage");
    }
    
    [self clearCellSelections];
    [self.selectedPhotos removeAllObjects];
}

- (UIImage*)loadFullsizeImage:(NSString*)filename {
    UIImage* image = [_fullsizedImageCache objectForKey:filename];
    if( !image ) {
        image = [UIImage imageWithContentsOfFile:filename];
        [_fullsizedImageCache setObject:image forKey:filename];
    }
    return image;
}

// TODO: remove this debug code
- (IBAction)debugInjectPressed:(id)sender {
    
    NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
    NSString* filename;
    
    // for ( int i=0 ; i < 3 ; i+=1 ) {
    if( !debugJPGdone ) {
        
        filename = [thisBundle pathForResource:@"debug1" ofType:@"jpg"];
        NSLog(@"debugInjectPressed: filename is %@", filename);
        debugJPGdone = TRUE;
    } else {
        filename = [thisBundle pathForResource:@"debug2" ofType:@"jpg"];
        NSLog(@"debugInjectPressed: filename is %@", filename);
        debugJPGdone = FALSE;
    }
    //    UIImage* debugImg = [self loadFullsizeImage:filename];
    
    NSNotification *notif = [NSNotification notificationWithName:@"debug" object:nil userInfo:[NSMutableDictionary dictionaryWithObject:filename forKey:@"path"]];
    [self addToRightSideOfCollectionView:notif];
    //  }
    
    
    
}

- (IBAction)newPhotosButtonPressed:(id)sender {
    NSLog(@"NewPhotosButtonPressed");
    [self.notificationOfNewPhotosViewOutlet setHidden:TRUE];
    
    if( sender == self.notificationOfNewPhotosButtonOutlet && _oldestNewestIndexPath != nil ) {
        NSLog(@"... scrolling right");
        [self.collectionView scrollToItemAtIndexPath:_oldestNewestIndexPath atScrollPosition:UICollectionViewScrollPositionLeft animated:TRUE];
    }
}

- (void)updatePreview {
    @synchronized( _previewIsShown ) {
        
        if( self.selectedPhotos.count > 6 ) {
            NSAssert(FALSE, @"Don't poke me! UpdatePreview cannot handle more than 6 images yet.");
            return;
        }
        if( self.selectedPhotos.count < 2 ) {
            if( _previewIsShown.boolValue ) {
                // TODO: going from 3 to 2 selected images -- hide/destroy preview, inform?
                
                _previewIsShown = [NSNumber numberWithBool:FALSE];
            } else {
                // TODO: going from 0->1 selected images -- inform user to pick another?
            }
            return;
        }
        
        BPPAirprintCollagePrinter* ap = [BPPAirprintCollagePrinter singleton];
        NSArray* selectedPhotosArray = [self.selectedPhotos allValues];
        UIImage* updatedPreview = [ap makeCollageImages:[NSArray arrayWithObject:selectedPhotosArray]][0];
        
        CGRect pos;
        if( updatedPreview.size.width > updatedPreview.size.height )
            pos = CGRectMake(200, 300, CollageLongsidePixels/5, CollageShortsidePixels/5);
        else
            pos = CGRectMake(200, 300, CollageShortsidePixels/5, CollageLongsidePixels/5);
        
        UIImageView* previewIView = [[UIImageView alloc] initWithFrame:pos];
        previewIView.image = updatedPreview;
        [self.view addSubview:previewIView];
        _previewIsShown = [NSNumber numberWithBool:TRUE];
        
    }
}

@end
