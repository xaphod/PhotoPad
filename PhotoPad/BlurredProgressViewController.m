//
//  BlurredProgressViewController.m
//  iOSync
//
//  Created by Tim Carr on 2/3/14.
//  Copyright (c) 2014 Swisscom AG. All rights reserved.
//

#import "BlurredProgressViewController.h"

@interface BlurredProgressViewController ()

@end


@implementation BlurredProgressViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _snapSemaphore = dispatch_semaphore_create(0);
        _dismissSemaphore = dispatch_semaphore_create(0);
        _processed = FALSE;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    [self.view setBackgroundColor:[UIColor clearColor]];
    
}

- (void)viewWillAppear:(BOOL)animated {
    if( ! _processed ) {
        NSLog(@"Debug, BlurredPC_VC: viewWillAppear, wait for semaphore");
        dispatch_semaphore_wait(_snapSemaphore, DISPATCH_TIME_FOREVER);
        NSLog(@"Debug, BlurredPC_VC: semaphore done, finishing viewWillAppear");

        int width = self.view.frame.size.width;
        int height = self.view.frame.size.height;
        
        //Add UIImageView to current view.
        UIImageView* blurView = [[UIImageView alloc] initWithFrame:self.view.bounds];
        blurView.image = _outputImg;
        
        RZSquaresLoading* loadingAnimationView = [[RZSquaresLoading alloc] initWithFrame:CGRectMake((width/2 - 18), (height/2 - 18), 36, 36)];
        loadingAnimationView.color = [UIColor orangeColor];
        
        UIView* innerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
        [innerView setBackgroundColor:[UIColor blackColor]];
        [innerView setAlpha:0.5f];
        
        _topContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
        [_topContainerView addSubview:innerView];
        [_topContainerView insertSubview:blurView belowSubview:innerView];
        [_topContainerView addSubview:loadingAnimationView];
        
        [_topContainerView setAlpha:0.0f];
        [self.view addSubview:_topContainerView];
        
        _processed = TRUE;
    }
    
}

- (void)viewDidAppear:(BOOL)animated {
    [UIView animateWithDuration:0.3f animations:^{
        [_topContainerView setAlpha:1.0f];
    }];
    dispatch_semaphore_signal(_dismissSemaphore);
}

- (void)viewWillDisappear:(BOOL)animated {
    [UIView animateWithDuration:0.3f animations:^{
        [_topContainerView setAlpha:0.0f];
    } completion:^(BOOL finished) {
        if( finished )
            _outputImg = nil;
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// returns a progress indicator view - takes current view (self.view) as input because it makes a blurred image of it. Achtung: the view returned comes with alpha 0.0 (transparent) !
- (void)snapScreenNow:(UIView*)view {
    _processed = FALSE; // re-use the view
    
    // Note to self: to not work with UIKit stuff on background threads, which includes anything to do with a UIView!
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // source: http://www.youtube.com/watch?feature=player_embedded&v=JIdcYbAd-NI
        // source2: http://stackoverflow.com/questions/12910625/cigaussianblur-and-ciaffineclamp-on-ios-6
        // source3: http://www.tnoda.com/blog/2013-05-26
    
        NSLog(@"Async CIAffine/Clamp/GaussianBlur start");
        
        //Get a screen capture from the current view.
        UIGraphicsBeginImageContext(view.bounds.size);
        [view.layer renderInContext:UIGraphicsGetCurrentContext()];
        UIImage *viewImg = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        //Blur the image
        CIImage *blurImg = [CIImage imageWithCGImage:viewImg.CGImage];
        
        CGAffineTransform transform = CGAffineTransformIdentity;
        CIFilter *clampFilter = [CIFilter filterWithName:@"CIAffineClamp"];
        [clampFilter setValue:blurImg forKey:@"inputImage"];
        [clampFilter setValue:[NSValue valueWithBytes:&transform objCType:@encode(CGAffineTransform)] forKey:@"inputTransform"];
        
        CIFilter *gaussianBlurFilter = [CIFilter filterWithName: @"CIGaussianBlur"];
        [gaussianBlurFilter setValue:clampFilter.outputImage forKey: @"inputImage"];
        [gaussianBlurFilter setValue:[NSNumber numberWithFloat:3.0f] forKey:@"inputRadius"];
        
        CIContext *context = [CIContext contextWithOptions:nil];
        CGImageRef cgImg = [context createCGImage:gaussianBlurFilter.outputImage fromRect:[blurImg extent]];
        @synchronized( _outputImg ) {
            _outputImg = [UIImage imageWithCGImage:cgImg];
        }
        CGImageRelease(cgImg);
    
        NSLog(@"Async CIAffine/Clamp/GaussianBlur end");

        dispatch_semaphore_signal(_snapSemaphore);
    });
}

- (void)dismiss {
    NSLog(@"Debug, BlurredPC_VC: dismiss: waiting for semaphore");
    dispatch_semaphore_wait(_dismissSemaphore, 0);
    NSLog(@"Debug, BlurredPC_VC: done semaphore, finishing dismiss");
    [self dismissViewControllerAnimated:FALSE completion:nil];
}


@end
