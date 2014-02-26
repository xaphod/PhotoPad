//
//  BPPViewPickerViewController.m
//  PhotoPad
//
//  Created by Tim Carr on 2/25/14.
//  Copyright (c) 2014 Albert Martin. All rights reserved.
//

#import "BPPViewPickerViewController.h"

@interface BPPViewPickerViewController ()

@end

@implementation BPPViewPickerViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    if( [[NSThread currentThread] isMainThread])
        NSLog(@"Main thread looks to be %@", [NSThread currentThread]);
    else
        NSLog(@"NOT MAIN THREAD?!");
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
