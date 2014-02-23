//
//  BPPMainViewController.h
//  PhotoPad
//
//  Created by Albert Martin on 11/20/13.
//  Copyright (c) 2013 Albert Martin. All rights reserved.
//

#import "MWPhotoBrowser.h"

#define DEVICE_IS_LANDSCAPE UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)

#define cellBorderPixels 10

@interface BPPMainViewController : UIViewController <MWPhotoBrowserDelegate, UIGestureRecognizerDelegate, UIActionSheetDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout> 

@property (strong, nonatomic) NSMutableArray *photoFilenames; // array of filenames with absolute paths
@property (strong, nonatomic) MWPhotoBrowser *photosBrowser;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (strong, nonatomic) UIActionSheet *photoToolSheet;

@property (nonatomic) NSUInteger selectedIndex;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *printButtonOulet;
@property (weak, nonatomic) IBOutlet UICollectionViewFlowLayout *collectionViewFlowLayout;


@property(nonatomic, strong) NSMutableDictionary* selectedPhotos; // key = filename (from photos array), value = UIImage*

- (UIImage *)imageWithImage:(UIImage *)image scaledToFillSize:(CGSize)size;

@end
