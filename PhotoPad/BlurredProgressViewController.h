//
//  BlurredProgressViewController.h
//  iOSync
//
//  Created by Tim Carr on 2/3/14.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreImage/CoreImage.h>
#import "RZSquaresLoading.h"

@interface BlurredProgressViewController : UIViewController {

    UIView* _topContainerView;
    UIImage* _outputImg;
    dispatch_semaphore_t _dismissSemaphore;
    dispatch_semaphore_t _snapSemaphore;
}

- (void)snapScreenNow:(UIView*)view ;
- (void)dismiss;

// set this to true if you will call snapScreenNow and then immediately show the view
@property bool synchronousMode;

@end
