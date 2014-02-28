//
//  BPPPreviewViewController.h
//  PhotoPad
//
//  Created by Tim Carr on 2/25/14.
//  Copyright (c) 2014 Tim Carr. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MWPhotoBrowser.h"

#define DEVICE_IS_LANDSCAPE UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)

//#define cellBorderPixels 5
#define cellInsets 5


@interface BPPPreviewViewController : UIViewController <MWPhotoBrowserDelegate, UIGestureRecognizerDelegate, UIActionSheetDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout,
    UIScrollViewDelegate>

// @property (strong, nonatomic) NSMutableArray *photoFilenames; // array of filenames with absolute paths

@property(nonatomic, strong) NSMutableDictionary* selectedPhotos; // key = URL (from PhotoStore), value = UIImage*
@property (nonatomic) NSUInteger selectedIndex;

@property (strong, nonatomic) MWPhotoBrowser *photosBrowser;


// UI

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;

@property (weak, nonatomic) IBOutlet UICollectionViewFlowLayout *collectionViewFlowLayoutOutlet;

@property (strong, nonatomic) UIActionSheet *photoToolSheet;

@property (weak, nonatomic) IBOutlet UIView *previewContainingViewOutlet;
@property (weak, nonatomic) IBOutlet UIImageView *previewImageViewOutlet;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *printButtonOulet;
@property (weak, nonatomic) IBOutlet UIView *notificationOfNewPhotosViewOutlet;
@property (weak, nonatomic) IBOutlet UIButton *notificationOfNewPhotosButtonOutlet;

// imageViewConstraints
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *previewImageViewConstraintLeft;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *previewImageViewConstraintBottom;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *previewImageViewConstraintTop;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *previewImageViewConstraintRight;



@end
