//
//  BPPPreviewViewController.h
//  PhotoPad
//
//  Created by Tim Carr on 2/25/14.
//  Copyright (c) 2014 Tim Carr. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MWPhotoBrowser.h"
#import "RZSquaresLoading.h"

#define DEVICE_IS_LANDSCAPE UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)

//#define cellBorderPixels 5
#define cellInsets 5


@interface BPPPreviewViewController : UIViewController <MWPhotoBrowserDelegate, UIGestureRecognizerDelegate, UIActionSheetDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout,
    UIScrollViewDelegate>

//@property(nonatomic, strong) NSMutableDictionary* selectedPhotos; // key = URL (from PhotoStore), value = UIImage*
@property (nonatomic) NSUInteger selectedIndex;

@property (strong, nonatomic) MWPhotoBrowser *photosBrowser;


// UI

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;

@property (weak, nonatomic) IBOutlet UICollectionViewFlowLayout *collectionViewFlowLayoutOutlet;

@property (strong, nonatomic) UIActionSheet *photoToolSheet;

@property (weak, nonatomic) IBOutlet UIView *previewContainingViewOutlet;
@property (weak, nonatomic) IBOutlet UIImageView *landscapeImageViewOutlet;
@property (weak, nonatomic) IBOutlet UIImageView *portraitImageViewOutlet;
@property (weak, nonatomic) IBOutlet UIView *notificationOfNewPhotosViewOutlet;
@property (weak, nonatomic) IBOutlet UIButton *notificationOfNewPhotosButtonOutlet;
@property (weak, nonatomic) IBOutlet UIButton *clearButtonOutlet;
@property (weak, nonatomic) IBOutlet UIButton *printButtonOutlet;
@property (strong, nonatomic) IBOutlet RZSquaresLoading *loadingAnimationStrongOutlet;


@end
