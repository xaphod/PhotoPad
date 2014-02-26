//
//  BPPPreviewViewController.h
//  PhotoPad
//
//  Created by Tim Carr on 2/25/14.
//  Copyright (c) 2014 Albert Martin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MWPhotoBrowser.h"

#define DEVICE_IS_LANDSCAPE UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)

#define cellBorderPixels 10
#define cellInsets 5


@interface BPPPreviewViewController : UIViewController <MWPhotoBrowserDelegate, UIGestureRecognizerDelegate, UIActionSheetDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

// @property (strong, nonatomic) NSMutableArray *photoFilenames; // array of filenames with absolute paths

@property(nonatomic, strong) NSMutableDictionary* selectedPhotos; // key = filename (from photos array), value = UIImage*

@property (strong, nonatomic) MWPhotoBrowser *photosBrowser;


// UI

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;

@property (weak, nonatomic) IBOutlet UICollectionViewFlowLayout *collectionViewFlowLayoutOutlet;

@property (strong, nonatomic) UIActionSheet *photoToolSheet;

@property (nonatomic) NSUInteger selectedIndex;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *printButtonOulet;
@property (weak, nonatomic) IBOutlet UIView *notificationOfNewPhotosViewOutlet;
@property (weak, nonatomic) IBOutlet UIButton *notificationOfNewPhotosButtonOutlet;

@end
