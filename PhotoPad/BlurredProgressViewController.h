//
//  BlurredProgressViewController.h
//  iOSync
//
//  Created by Tim Carr on 2/3/14.
//  Copyright (c) 2014 Swisscom AG. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreImage/CoreImage.h>
#import "RZSquaresLoading.h"

@interface BlurredProgressViewController : UIViewController {

    UIView* _topContainerView;
    UIImage* _outputImg;
    bool _processed;
    dispatch_semaphore_t _dismissSemaphore;
    dispatch_semaphore_t _snapSemaphore;
}

- (void)snapScreenNow:(UIView*)view ;
- (void)dismiss;

@end
