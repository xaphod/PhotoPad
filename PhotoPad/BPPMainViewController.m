//
//  BPPMainViewController.m
//  PhotoPad
//
//  Created by Albert Martin on 11/20/13.
//  Copyright (c) 2013 Albert Martin. All rights reserved.
//

#import "BPPMainViewController.h"
#import "BPPGalleryCell.h"
#import "NSFileManager+Tar.h"
#import "UIColor+Hex.h"
#import "BPPAirprintCollagePrinter.h"

@interface BPPMainViewController () {
    NSOperationQueue* _resizedImageCacheOperationQueue;
    NSCache* _resizedImageCache;
    NSCache* _fullsizedImageCache;
    
    // DEBUG: ReMOVE THIS
    bool debugJPGdone;
}

@end

@implementation BPPMainViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self updateUIFromSettings];
	
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(updateUIFromSettings)
                                                name:NSUserDefaultsDidChangeNotification
                                              object:nil];
    
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(addToTopOfGallery:)
                                                name:@"EyeFiUnarchiveComplete"
                                              object:nil];
    
    _photoFilenames = [NSMutableArray array];
    _photosNotYetAdded = [NSMutableArray array];
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
    
    // when the collectionView is pulled from top, it should be refreshed
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(newPhotosButtonPressed:)
             forControlEvents:UIControlEventValueChanged];
    self.collectionView.alwaysBounceVertical = YES;
    [self.collectionView addSubview:refreshControl];
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

- (void)addToTopOfGallery:(NSNotification *)notification
{
    NSLog(@"AddToTopOfGallery: START, currentThread %@", [NSThread currentThread]);
    
    NSString* filename = [notification.userInfo objectForKey:@"path"];
    
    if( [self.collectionView.indexPathsForVisibleItems containsObject:[NSIndexPath indexPathForItem:0 inSection:0]] ) {
        [self.photoFilenames insertObject:filename atIndex:0];
        [self.collectionView insertItemsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForItem:0 inSection:0]]];
        NSLog(@"... added directly to photos array / collectionView");
    } else {
        // show new photos UI indication
        [self.notificationOfNewPhotosViewOutlet setHidden:FALSE];
        [self.photosNotYetAdded addObject:filename];
        NSLog(@"... pending in queue (newPhotosNotYetAdded)!");
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
        CGSize size = [self getCellSize];
        size.width -= 2*cellBorderPixels;
        size.height-= 2*cellBorderPixels;
        
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
    /* tim - want to multi-select & print.
    [_photosBrowser reloadData];
    [_photosBrowser setCurrentPhotoIndex:indexPath.row];
    [self.navigationController pushViewController:_photosBrowser animated:YES];
     */
    
    BPPGalleryCell *cell = (BPPGalleryCell*)[collectionView cellForItemAtIndexPath:indexPath];
    [cell.checkmarkViewOutlet setChecked:YES];
    
    NSString *filename = [self.photoFilenames objectAtIndex:indexPath.row];
    [self.selectedPhotos setObject:[self loadFullsizeImage:filename] forKey:filename];
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    BPPGalleryCell *cell = (BPPGalleryCell*)[collectionView cellForItemAtIndexPath:indexPath];
    [cell.checkmarkViewOutlet setChecked:NO];
    // TODO: all array ops should be in a function that captures exceptions?
    NSString *filename = [self.photoFilenames objectAtIndex:indexPath.row];
    [self.selectedPhotos removeObjectForKey:filename];
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(10, 10, 85, 10);
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return [self getCellSize];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [_resizedImageCache removeAllObjects];
    [self.collectionViewFlowLayout invalidateLayout];
}

- (CGSize)getCellSize {
    
    int squareSize = self.view.frame.size.width;

    if( DEVICE_IS_LANDSCAPE ) {
        // 3 per row
        squareSize -= 6 * cellBorderPixels;
        squareSize /= 3;
        //NSLog(@"landscape (div by 3), squaresize is %d", squareSize);
    } else {
        // 2 per row
        squareSize -= 4 * cellBorderPixels;
        squareSize /= 2;
        //NSLog(@"portrait (div by 2), squaresize is %d", squareSize);
    }
    return CGSizeMake(squareSize, squareSize);
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
    
    [self addToTopOfGallery:notif];
    
}

- (IBAction)newPhotosButtonPressed:(id)sender {
    NSLog(@"NewPhotosButtonPressed");
    [self.notificationOfNewPhotosViewOutlet setHidden:TRUE];
    
    if( sender == self.notificationOfNewPhotosButtonOutlet) {
        NSLog(@"... button pressed, so scrolling up");
        [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0] atScrollPosition:UICollectionViewScrollPositionTop animated:TRUE];
    }

    [self.collectionView performBatchUpdates:^{
        for( id object in self.photosNotYetAdded ) {
            [self.photoFilenames insertObject:object atIndex:0];
            [self.collectionView insertItemsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForItem:0 inSection:0]]];
        }
    } completion:^(BOOL finished) {
    }];
}


@end
