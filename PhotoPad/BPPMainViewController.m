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
                                            selector:@selector(updateGallery:)
                                                name:@"EyeFiUnarchiveComplete"
                                              object:nil];
    
    // Create array of `MWPhoto` objects
    _photos = [[NSMutableArray array] init];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    [_photos addObjectsFromArray: [[NSBundle bundleWithPath:[paths objectAtIndex:0]] pathsForResourcesOfType:@".JPG" inDirectory:nil]];
    
    // Setup the photo browser.
    _photosBrowser = [[MWPhotoBrowser alloc] initWithDelegate:self];
    [_photosBrowser showPreviousPhotoAnimated:YES];
    [_photosBrowser showNextPhotoAnimated:YES];
    
    // Setup a long press to reveal an action menu.
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(activateActionMode:)];
    longPress.delegate = self;
    [_galleryView addGestureRecognizer:longPress];
    self.photoToolSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Delete" otherButtonTitles:nil];
    
    self.galleryView.allowsMultipleSelection = YES;
    self.selectedPhotos = [NSMutableArray array];
    
    _resizedImageCache = [[NSCache init] alloc];
    _resizedImageCacheOperationQueue = [[NSOperationQueue init] alloc];
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
    NSLog(@"Perf debug: imageWithImage. Width %f, height %f", width, height);
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

- (void)updateGallery:(NSNotification *)notification
{
    [self.photos addObject: [notification.userInfo objectForKey:@"path"]];
    [self.galleryView reloadData];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"EyeFiCommunication" object:nil userInfo:[NSDictionary dictionaryWithObject:@"GalleryUpdated" forKey:@"method"]];
}

#pragma mark - Photo Gallery

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.photos.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    BPPGalleryCell *cell = (BPPGalleryCell *)[collectionView dequeueReusableCellWithReuseIdentifier:@"PhotoCell" forIndexPath:indexPath];
    
    // TODO: this is probably why it is slow to scroll - this is a resize from full JPG. need to save these off as individual items
    
    // approach: use an NSCache, with an NSOperationQueue that limits the number of concurrent ops to 3.
    
    CGSize size = [self getCellSize];
    size.width -= 2*cellBorderPixels;
    size.height-= 2*cellBorderPixels;
    
    cell.asset = [self imageWithImage: [UIImage imageWithContentsOfFile:self.photos[indexPath.row]] scaledToFillSize:size];
    cell.backgroundColor = [UIColor whiteColor];
    //NSLog(@"cellForItemAtIndexPath: cell size width %d, height %d", (int)cell.frame.size.width, (int)cell.frame.size.width);
    
    return cell;
}

/*
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section
{
    return 5;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section
{
    return 5;
}
 */

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    /* tim - want to multi-select & print.
    [_photosBrowser reloadData];
    [_photosBrowser setCurrentPhotoIndex:indexPath.row];
    [self.navigationController pushViewController:_photosBrowser animated:YES];
     */
    
    BPPGalleryCell *cell = (BPPGalleryCell*)[collectionView cellForItemAtIndexPath:indexPath];
    [cell.checkmarkViewOutlet setChecked:YES];
    
    NSString *filename = [self.photos objectAtIndex:indexPath.row];
    [self.selectedPhotos addObject:[UIImage imageWithContentsOfFile:filename]];
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    BPPGalleryCell *cell = (BPPGalleryCell*)[collectionView cellForItemAtIndexPath:indexPath];
    [cell.checkmarkViewOutlet setChecked:NO];
    [self.selectedPhotos removeObject:[self.photos objectAtIndex:indexPath.row]];
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(10, 10, 0, 10);
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return [self getCellSize];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
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
        NSIndexPath *indexPath = [_galleryView indexPathForItemAtPoint:[gr locationInView:_galleryView]];
        UICollectionViewLayoutAttributes *cellAtributes = [_galleryView layoutAttributesForItemAtIndexPath:indexPath];
        self.selectedIndex = indexPath.row;
        [self.photoToolSheet showFromRect:cellAtributes.frame inView:_galleryView animated:YES];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0) {
        // Delete button was pressed.
        [[NSFileManager defaultManager] removeItemAtPath:[_photos objectAtIndex:_selectedIndex] error:nil];
        [_photos removeObjectAtIndex:_selectedIndex];
        [_galleryView reloadData];
    }
}

#pragma mark - Photo Browser

- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser {
    return self.photos.count;
}

- (MWPhoto *)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
    if (index < self.photos.count)
        return [MWPhoto photoWithImage:[UIImage imageWithContentsOfFile:[self.photos objectAtIndex:index]]];
    return nil;
}

#pragma mark - Printing

- (IBAction)PrintPressed:(id)sender {
    NSLog(@"PrintPressed, %lu photos to print.", (unsigned long)self.selectedPhotos.count);
    
    // TODO: progress indicator -- printCollage takes about 0.5s until it shows iOS print ui

    BPPAirprintCollagePrinter *ap = [BPPAirprintCollagePrinter singleton];
    
    if( ! [ap printCollage:self.selectedPhotos fromUIBarButton:self.printButtonOulet] ) {
        NSLog(@"MainVC, got fail for printCollage");
    }

    
    /*
    UIImageView* iv = [[UIImageView alloc] initWithImage:[UIImage imageWithData:thisDebugJPG]];
    [iv setFrame:CGRectMake(0, 0, 1200, 1800)];
    [self.view addSubview:iv];
    */
    
    [self clearCellSelections];
    [self.selectedPhotos removeAllObjects];
}

- (void)clearCellSelections {
    int collectionViewCount = [self.galleryView numberOfItemsInSection:0];
    for (int i=0; i<=collectionViewCount; i++) {
        [self.galleryView deselectItemAtIndexPath:[NSIndexPath indexPathForItem:i inSection:0] animated:YES];
    }
}

@end
