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
#import "BPPPhotoStore.h"

@interface BPPPreviewViewController () {
    CGFloat cellSize;
    NSIndexPath* _oldestNewestIndexPath;
    UIImageView* _previewImageView;
    BPPPhotoStore* photoStore;
    
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
	
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(updateUIFromSettings)
                                                name:NSUserDefaultsDidChangeNotification
                                              object:nil];
    
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(photoReceivedFromEyeFi:)
                                                name:@"EyeFiUnarchiveComplete"
                                              object:nil];
    
    //_photoFilenames = [NSMutableArray array];
    //NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    // [_photoFilenames addObjectsFromArray: [[NSBundle bundleWithPath:[paths objectAtIndex:0]] pathsForResourcesOfType:@".JPG" inDirectory:nil]];
    // want to display newest at top
    // // [_photoFilenames sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    // // _photoFilenames = [[[_photoFilenames reverseObjectEnumerator] allObjects] mutableCopy];



    
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
    
    photoStore = [BPPPhotoStore singleton]; // ask for permission to photos, etc
    [photoStore setReloadTarget:self.collectionView];
}

- (void)viewDidAppear:(BOOL)animated
{
    // TODO: bring back help
    // Show help if the user has not defined a card key.
    /*
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"upload_key"]) {
        [self performSegueWithIdentifier:@"showHelp" sender: self];
    }
     */
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

- (void)photoReceivedFromEyeFi:(NSNotification *)notification
{
    NSString* filename = [notification.userInfo objectForKey:@"path"];
    NSLog(@"photoReceivedFromEyeFi: START filename %@, currentThread %@", filename,  [NSThread currentThread]);
    
    int numItemsBeforeInsert = (int)photoStore.photoURLs.count;
    
    [photoStore loadFromFileAndDelete:filename completionBlock:^{
        
        NSAssert(photoStore.photoURLs.count == numItemsBeforeInsert+1, @"photoReceivedFromEyeFi: Stopping because the item did not get added.");
        
        // rest is capable of adding more than one item...
        [UIView setAnimationsEnabled:NO];
        NSMutableArray *arrayWithIndexPaths = [NSMutableArray array];
        for (int i = numItemsBeforeInsert; i < numItemsBeforeInsert + 1; i++)
            [arrayWithIndexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
        
        if( numItemsBeforeInsert == 0 ) {
            [self.collectionView reloadData];
        } else {
            [self.collectionView performBatchUpdates:^{
                [self.collectionView insertItemsAtIndexPaths:arrayWithIndexPaths];
            } completion:^(BOOL finished) {
                [UIView setAnimationsEnabled:YES];
            }];
        }
        
        if( self.notificationOfNewPhotosViewOutlet.hidden ) {
            if( ! [self.collectionView.indexPathsForVisibleItems containsObject:arrayWithIndexPaths[0]] ) {
                // first item we just added not visible
                _oldestNewestIndexPath = arrayWithIndexPaths[0];
                self.notificationOfNewPhotosViewOutlet.hidden = FALSE;
            }
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"EyeFiCommunication" object:nil userInfo:[NSDictionary dictionaryWithObject:@"GalleryUpdated" forKey:@"method"]];
    }];

}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    NSLog(@"numberOfItemsInSection: returning %d", (int)photoStore.photoURLs.count);
    return photoStore.photoURLs.count;
}


- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    BPPGalleryCell *cell = (BPPGalleryCell *)[collectionView dequeueReusableCellWithReuseIdentifier:@"PhotoCell" forIndexPath:indexPath];
    
    // cells don't remember their state
    cell.backgroundColor = [UIColor whiteColor];
    
    // THE COLLECTIONVIEW IS KEYED ON THE URLs
    NSString *url = photoStore.photoURLs[indexPath.row];
    
    if( [self.selectedPhotos objectForKey:url] != nil ) {
        [cell.checkmarkViewOutlet setChecked:YES];
        cell.selected = TRUE;
    } else {
        [cell.checkmarkViewOutlet setChecked:NO];
        cell.selected = FALSE;
    }
    
    CGSize size = CGSizeMake(cellSize, cellSize);

    UIImage* instantResult = [photoStore getResizedImage:photoStore.photoURLs[indexPath.row] size:size completionBlock:^(UIImage *resizedImage) {

        if( [_collectionView.indexPathsForVisibleItems containsObject:indexPath] ) {
            // Get hold of main queue (main thread)
            [[NSOperationQueue mainQueue] addOperationWithBlock: ^ {
                BPPGalleryCell *thisCell = (BPPGalleryCell*)[_collectionView cellForItemAtIndexPath:indexPath];
                thisCell.asset = resizedImage;
            }];
        }
    }];
    
    if( instantResult != nil )
        cell.asset = instantResult;

    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    BPPGalleryCell *cell = (BPPGalleryCell*)[collectionView cellForItemAtIndexPath:indexPath];
    [cell.checkmarkViewOutlet setChecked:YES];
    
    NSString *url = photoStore.photoURLs[indexPath.row];
    [photoStore getFullsizeImage:url completionBlock:^(UIImage *fullsizeImage) {
        [self.selectedPhotos setObject:fullsizeImage forKey:url];
        [self updatePreview];
    }];

}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    BPPGalleryCell *cell = (BPPGalleryCell*)[collectionView cellForItemAtIndexPath:indexPath];
    [cell.checkmarkViewOutlet setChecked:NO];
    [self.selectedPhotos removeObjectForKey:photoStore.photoURLs[indexPath.row]];
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
    [photoStore viewControllerIsRotating];
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
        NSString* url = photoStore.photoURLs[_selectedIndex];
        [photoStore deletePhoto:url];
        [_collectionView deleteItemsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForItem:_selectedIndex inSection:0]]];
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
    return photoStore.photoURLs.count;
}

- (MWPhoto *)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
    // TODO: fix me if you want MWPhotoBrowser
/*    if (index < photoStore.photoURLs.count)
        return [MWPhoto photoWithImage:[photoStore getFullsizeImageSynchronous:photoStore.photoURLs[index]]];
*/
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
    [self photoReceivedFromEyeFi:notif];
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
    @synchronized( _previewImageView ) {
        
        if( self.selectedPhotos.count > 6 ) {
            NSAssert(FALSE, @"Don't poke me! UpdatePreview cannot handle more than 6 images yet.");
            return;
        }
        if( self.selectedPhotos.count < 2 ) {
            if( _previewImageView != nil ) {
                // TODO: going from 3 to 2 selected images -- hide/destroy preview, inform?
                [UIView transitionWithView:_previewImageView
                                  duration:1.0f
                                   options:UIViewAnimationOptionTransitionCrossDissolve
                                animations:^{
                                    _previewImageView.image = nil;
                                } completion:nil];
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
            pos = CGRectMake(100, 300, CollageLongsidePixels/3, CollageShortsidePixels/3);
        else
            pos = CGRectMake(100, 300, CollageShortsidePixels/3, CollageLongsidePixels/3);
        
        if( _previewImageView== nil ) {
            _previewImageView = [[UIImageView alloc] initWithFrame:pos];
            [self.view addSubview:_previewImageView];
        }
        
        [UIView transitionWithView:_previewImageView
                          duration:0.7f
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
                            _previewImageView.image = updatedPreview;
                        } completion:nil];
        
        
    }
}


@end