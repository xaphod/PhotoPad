//
//  BPPPreviewViewController.m
//  PhotoPad
//
//  Created by Tim Carr on 2/25/14.
//  Copyright (c) 2014 Tim Carr. All rights reserved.
//

#import "BPPPreviewViewController.h"
#import "BPPGalleryCell.h"
#import "NSFileManager+Tar.h"
#import "UIColor+Hex.h"
#import "BPPAirprintCollagePrinter.h"
#import "BPPPhotoStore.h"
#import "BPPAppDelegate.h"

@interface BPPPreviewViewController () {
    CGFloat cellSize;
    NSIndexPath* _oldestNewestIndexPath;
    BPPPhotoStore* photoStore;
    dispatch_semaphore_t _previewSemaphore;

    // DEBUG: ReMOVE THIS
    bool debugJPGdone;
}

@end

@implementation BPPPreviewViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // show loading animation until loading images from camera roll is complete
    self.loadingAnimationStrongOutlet = [[RZSquaresLoading alloc] initWithFrame:self.loadingAnimationStrongOutlet.frame];
    [self.loadingAnimationStrongOutlet setColor:[UIColor orangeColor]];
    self.loadingAnimationStrongOutlet.hidden = NO;
    self.loadingAnimationStrongOutlet.alpha = 1.0;
    [self.previewContainingViewOutlet addSubview:self.loadingAnimationStrongOutlet];
    
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
    
    
    // Setup the photo browser.
    _photosBrowser = [[MWPhotoBrowser alloc] initWithDelegate:self];
    [_photosBrowser showPreviousPhotoAnimated:YES];
    [_photosBrowser showNextPhotoAnimated:YES];
    
    // Setup a long press to reveal an action menu.
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(activateActionMode:)];
    longPress.delegate = self;
    [_collectionView addGestureRecognizer:longPress];
    self.photoToolSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Delete" otherButtonTitles:nil];
    
    longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(emailButtonLongPress:)];
    longPress.minimumPressDuration = 3; // 3 seconds pressing to activate!
    [self.emailButtonOutlet addGestureRecognizer:longPress];

    
    self.collectionView.allowsMultipleSelection = YES;
    
    photoStore = [BPPPhotoStore singletonWithLargestPreviewSize:(self.landscapeImageViewOutlet.frame.size.width * [UIScreen mainScreen].scale) shortsidePixels:(self.landscapeImageViewOutlet.frame.size.height * [UIScreen mainScreen].scale) ]; // ask for permission to photos, etc
    [photoStore registerCallbackAfterCameraRollLoadComplete:self selector:@selector(loadingImagesComplete)];
    
    _previewSemaphore = dispatch_semaphore_create(1);
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
    NSLog(@"\n\n\n************************MEMORY WARNING BPPPreviewVC!************************\n\n\n");
    self.landscapeImageViewOutlet.image = nil;
    self.portraitImageViewOutlet.image = nil;
    [photoStore didReceiveMemoryWarning];
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

// called by photostore when loading is complete, and when an image is removed (URL deleted) from camera roll
- (void)loadingImagesComplete {
    [self.collectionView reloadData];
    [self.loadingAnimationStrongOutlet setAlpha:0.0];
    [self.loadingAnimationStrongOutlet setHidden:YES];
}


#pragma mark - Photo Gallery

- (void)photoReceivedFromEyeFi:(NSNotification *)notification
{
    // THIS METHOD RUNS CONCURRENTLY VIA MULTIPLE THREADS
    
    NSString* filename = [notification.userInfo objectForKey:@"path"];
    NSLog(@"photoReceivedFromEyeFi: START filename %@, currentThread %@", filename,  [NSThread currentThread]);
    
    int numItemsBeforeInsert = (int)photoStore.photoURLs.count;
    
    [photoStore loadFromFileAndDelete:filename completionBlock:^{
        
        NSAssert(photoStore.photoURLs.count >= numItemsBeforeInsert+1, @"photoReceivedFromEyeFi: Stopping because the item did not get added.");
        
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
    
    if( [self checkIfIndexPathIsSelected:indexPath] ) {
        [cell.checkmarkViewOutlet setChecked:YES];
        cell.selected = TRUE;
    } else {
        [cell.checkmarkViewOutlet setChecked:NO];
        cell.selected = FALSE;
    }
    
    CGSize size = CGSizeMake(cellSize, cellSize);
    
    __weak UICollectionView* weakCollectionView = collectionView;
    
    [photoStore getCellsizeImage:url size:size completionBlock:^(UIImage *resizedImage) {
        
        // Get hold of main queue (main thread)
        [[NSOperationQueue mainQueue] addOperationWithBlock: ^ {
            
            BPPGalleryCell *thisCell = (BPPGalleryCell*)[weakCollectionView cellForItemAtIndexPath:indexPath];
            thisCell.asset = resizedImage;
        }];
    }];
    
    return cell;
}

// max 6 selected cells
- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if( self.collectionView.indexPathsForSelectedItems.count >= 6 ) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Maximum 6 Photos" message:@"The maximum number of photos is already selected. To clear the selection, use the clear button." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        return NO;
    }
    return YES;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    
    BPPGalleryCell *cell = (BPPGalleryCell*)[collectionView cellForItemAtIndexPath:indexPath];
    [cell.checkmarkViewOutlet setChecked:YES];

    NSString *url = photoStore.photoURLs[indexPath.row];
    
    __weak BPPPreviewViewController* weakSelf = self;
    
    [photoStore getHalfResolutionImage:url completionBlock:^(UIImage *resizedImage) {
        [[NSOperationQueue mainQueue] addOperationWithBlock: ^ {
            [weakSelf updatePreview];
        }];
    }];
    
    self.clearButtonOutlet.hidden = NO;

    NSLog(@"Finished selecting item");

}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    BPPGalleryCell *cell = (BPPGalleryCell*)[collectionView cellForItemAtIndexPath:indexPath];
    [cell.checkmarkViewOutlet setChecked:NO];
    
    if( collectionView.indexPathsForSelectedItems == nil || collectionView.indexPathsForSelectedItems.count == 0 )
        self.clearButtonOutlet.hidden = YES;

    [self updatePreview];
}

- (bool)checkIfURLIsSelected:(NSString*)url {
    for( NSIndexPath* thisPath in self.collectionView.indexPathsForSelectedItems ) {
        if( [photoStore.photoURLs[thisPath.row] isEqualToString:url] )
            return YES;
    }
    return NO;
}

- (bool)checkIfIndexPathIsSelected:(NSIndexPath*)indexPath {
    if( [self.collectionView.indexPathsForSelectedItems containsObject:indexPath] )
        return YES;
    return NO;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    if( cellSize == -1 ) {
        cellSize = self.collectionViewFlowLayoutOutlet.itemSize.height - 2*cellInsets;
        NSLog(@"Set cellSize to %f", cellSize);
    }
    return CGSizeMake(cellSize, cellSize);
}

// avoid cells having old images from before they were recycled
- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    BPPGalleryCell* thisCell = (BPPGalleryCell*)cell;
    thisCell.asset = nil;
}

// stop showing newimagesnotification when visible cell it was marking comes into view
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    NSArray* visibleIndexPaths = [self.collectionView indexPathsForVisibleItems];
    for( NSIndexPath* thisIndexPath in visibleIndexPaths ) {
        if( thisIndexPath.row >= _oldestNewestIndexPath.row ) {
            self.notificationOfNewPhotosViewOutlet.hidden = TRUE;
            return;
        }
    }
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
        // TODO: check, does doing delete also auto-do deselect? bet it doesn't
    }
}

- (void)clearCellSelections {
    NSLog(@"clearCellSelections begin");
    self.clearButtonOutlet.hidden = YES;
    
    NSArray* selectedIndexPaths = [self.collectionView indexPathsForSelectedItems];
    
    for( id indexPath in selectedIndexPaths ) {
        [self.collectionView deselectItemAtIndexPath:indexPath animated:YES];
        BPPGalleryCell *cell = (BPPGalleryCell*)[self.collectionView cellForItemAtIndexPath:indexPath];
        [cell.checkmarkViewOutlet setChecked:NO];
    }
    
    NSAssert(self.collectionView.indexPathsForSelectedItems.count == 0, @"Error, there shouldn't be anything selected when pressing clear");
    
    [photoStore cacheClean];
    [self updatePreview];
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
    NSLog(@"PrintPressed, %lu photos to print.", (unsigned long)self.collectionView.indexPathsForSelectedItems.count);
    
    // TODO: progress indicator -- printCollage takes about 0.5s until it shows iOS print ui
    
    [self gatherSelectedImages:YES finishedSelector:@selector(startPrinting:)];
}

- (void)startPrinting:(NSArray*)images {
    BPPAirprintCollagePrinter *ap = [BPPAirprintCollagePrinter singleton];
    
    
    
    if( ! [ap printCollage:images fromCGRect:self.printButtonOutlet.frame fromUIView:self.view successBlock:^{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Printing Successful" message:@"Your photo(s) will print soon. Please take the photo and put it in the wedding album for the happy couple, and write a nice message with it!" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        
        [self clearCellSelections];

    } failBlock:^(NSError *error) {
        NSString* displayStr = [NSString stringWithFormat:@"Oh no! The printer didn't work. Please go get Tim and tell him about it. Your pictures have been saved, so you can try again later.\n\nError -- descrip: %@, domain %@ with error code %d", error.localizedDescription, error.domain, (int)error.code];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Printing Error" message:displayStr delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        
    }] ) {
        NSLog(@"MainVC, got fail for printCollage");
    }

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

- (void)gatherSelectedImages:(SEL)finishedSelector {
    [self gatherSelectedImages:NO finishedSelector:finishedSelector];
}

- (void)gatherSelectedImages:(bool)forPrinting finishedSelector:(SEL)finishedSelector {
    
    if( self.collectionView.indexPathsForSelectedItems.count > 6 ) {
        NSAssert(FALSE, @"Don't poke me! cannot handle more than 6 images yet.");
        return;
    }
    if( self.collectionView.indexPathsForSelectedItems.count < 2 ) {
        if( self.landscapeImageViewOutlet.image != nil || self.portraitImageViewOutlet.image != nil ) {

            [UIView transitionWithView:self.previewContainingViewOutlet
                              duration:1.0f
                               options:UIViewAnimationOptionTransitionCrossDissolve
                            animations:^{
                                self.landscapeImageViewOutlet.image = nil;
                                self.portraitImageViewOutlet.image = nil;
                            } completion:nil];
        } else {
            // TODO: going from 0->1 selected images -- inform user to pick another?
            NSLog(@"NOT ENOUGH SELECTED PHOTOS");
        }
        
        self.loadingAnimationStrongOutlet.hidden = YES;
        self.loadingAnimationStrongOutlet.alpha = 0.0;

        return;
    }
    
    NSMutableArray* selectedPhotosArray = [NSMutableArray array];
    __weak NSMutableArray* weakSelectedPhotos = selectedPhotosArray;
    int stopTarget = (int)self.collectionView.indexPathsForSelectedItems.count;
    
    for( NSIndexPath* thisPath in self.collectionView.indexPathsForSelectedItems ) {
        NSString* url = photoStore.photoURLs[thisPath.row];
        
        [photoStore getHalfResolutionImage:url completionBlock:^(UIImage *resizedImage) {
                @synchronized( weakSelectedPhotos ) {
                    [weakSelectedPhotos addObject:resizedImage];
                    if( weakSelectedPhotos.count == stopTarget )
                        [self performSelectorOnMainThread:finishedSelector withObject:selectedPhotosArray waitUntilDone:NO];
                }
        }];
    }
}


- (void)updatePreview {
    NSLog(@"updatePreview: thread %@", [NSThread currentThread]);

    self.loadingAnimationStrongOutlet.hidden = NO;
    self.loadingAnimationStrongOutlet.alpha = 1.0;

    [self gatherSelectedImages:@selector(updatePreviewCallback:)];
}

- (void)updatePreviewCallback:(NSArray*)images {
    
    NSAssert(images.count >= 2, @"updatePreviewCallback must get called with at least 2 images");
    
    BPPAirprintCollagePrinter *ap = [BPPAirprintCollagePrinter singleton];
    
    bool landscape = [ap isResultingCollageLandscape:images];
    UIImageView* correctImageView = self.landscapeImageViewOutlet;
    UIImageView* wrongImageView = self.portraitImageViewOutlet;
    CGFloat longside = self.landscapeImageViewOutlet.frame.size.width * [UIScreen mainScreen].scale;
    CGFloat shortside= self.landscapeImageViewOutlet.frame.size.height * [UIScreen mainScreen].scale;
    
    if( ! landscape ) {
        correctImageView = self.portraitImageViewOutlet;
        wrongImageView = self.landscapeImageViewOutlet;
        longside = self.portraitImageViewOutlet.frame.size.height * [UIScreen mainScreen].scale;
        shortside= self.portraitImageViewOutlet.frame.size.width * [UIScreen mainScreen].scale;

        NSLog(@"updatePreview: landscape NO");
    } else {
        NSLog(@"updatePreview: landscape YES");
    }
    
    __weak dispatch_semaphore_t semaphore = _previewSemaphore;

    [ap makeCollageImages:[NSArray arrayWithObject:images] longsideLength:longside shortsideLength:shortside completionBlock:^(NSArray *collageImages) {
        
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            NSAssert(collageImages.count >= 1, @"Expected at least 1 result from makeCollageImages !");
            
            [UIView transitionWithView:self.previewContainingViewOutlet
                              duration:0.7f
                               options:UIViewAnimationOptionTransitionCrossDissolve
                            animations:^{
                                correctImageView.image = collageImages[0];
                                wrongImageView.image = nil;
                                self.loadingAnimationStrongOutlet.hidden = YES;
                                self.loadingAnimationStrongOutlet.alpha = 0.0;
                                
                            } completion:^(BOOL finished){
                            }];
        });

        dispatch_semaphore_signal(_previewSemaphore);
    }];
    
}

- (IBAction)clearPressed:(id)sender {
    [self clearCellSelections];
}

// email button long press
- (void)emailButtonLongPress:(UILongPressGestureRecognizer*)gesture {
    if ( gesture.state == UIGestureRecognizerStateEnded ) {
        NSLog(@"Email Long Press");
        
        UIAlertView *passwordAlert = [[UIAlertView alloc] initWithTitle:@"Password" message:@"" delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel",nil) otherButtonTitles:NSLocalizedString(@"OK",nil), nil];
        passwordAlert.alertViewStyle = UIAlertViewStyleSecureTextInput;
        [passwordAlert show];
        
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    
    // rough password check
    if( [[alertView textFieldAtIndex:0].text isEqualToString:@"rush2112"] ) {
        
        BPPAppDelegate *appDelegate = (BPPAppDelegate *)[[UIApplication sharedApplication] delegate];

        MFMailComposeViewController *mailController = [[MFMailComposeViewController alloc] init];
        
        // TODO: add support to set name of wedding in settings, and use it here in subject
        [mailController setSubject:@"Eyefi Booth - email addresses"];
        [mailController setMessageBody:[appDelegate getStringOfAllEmailAddresses] isHTML:NO];
        
        mailController.mailComposeDelegate = self;
        
       UINavigationController *myNavController = [self navigationController];
        
        if ( mailController != nil ) {
            if ([MFMailComposeViewController canSendMail]){
                [myNavController presentViewController:mailController animated:YES completion:^{
                    nil;
                }];
            } else {
                NSLog(@"ERROR: uh oh MFMailComposeVC cannot send mail!");
            }
        }

        // TODO: ofer to clear list of emails now it is sent
        
    }
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    [controller dismissViewControllerAnimated:YES completion:^{
        
    }];
}

@end
