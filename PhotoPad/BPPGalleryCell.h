//
//  BPPGalleryCell.h
//  PhotoPad
//
//  Created by Albert Martin on 11/22/13.
//  Copyright (c) 2013 Albert Martin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SSCheckMark.h"

@interface BPPGalleryCell : UICollectionViewCell

@property(nonatomic, strong) UIImage *asset;
@property (weak, nonatomic) IBOutlet SSCheckMark *checkmarkViewOutlet;

@end
