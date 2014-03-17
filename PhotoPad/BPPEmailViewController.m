//
//  BPPEmailViewController.m
//  PhotoPad
//
//  Created by Tim Carr on 3/2/14.
//  Copyright (c) 2014 Albert Martin. All rights reserved.
//

#import "BPPEmailViewController.h"
#import "BPPAppDelegate.h"

@interface BPPEmailViewController () {
    UITapGestureRecognizer* _gestureRecognizer;
}

@end

@implementation BPPEmailViewController

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
    
    NSString *htmlFile = [[NSBundle mainBundle] pathForResource:@"Email" ofType:@"html"];
    NSString* htmlString = [NSString stringWithContentsOfFile:htmlFile encoding:NSUTF8StringEncoding error:nil];
    [self.webViewOutlet loadHTMLString:htmlString baseURL:nil];
    
}

- (void)viewDidAppear:(BOOL)animated
{
    _gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapBehind:)];
    
    [_gestureRecognizer setNumberOfTapsRequired:1];
    _gestureRecognizer.cancelsTouchesInView = NO;
    [self.view.window addGestureRecognizer:_gestureRecognizer];

}

- (void)handleTapBehind:(UITapGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateEnded)
    {
        CGPoint location = [sender locationInView:nil]; //Passing nil gives us coordinates in the window
        
        //Then we convert the tap's location into the local view's coordinate system, and test to see if it's in or outside. If outside, dismiss the view.
        
        if (![self.view pointInside:[self.view convertPoint:location fromView:self.view.window] withEvent:nil])
        {
            // Remove the recognizer first so it's view.window is valid.
            [self.view.window removeGestureRecognizer:sender];
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(BOOL) NSStringIsValidEmail:(NSString *)checkString
{
    BOOL stricterFilter = NO; // Discussion http://blog.logichigh.com/2010/09/02/validating-an-e-mail-address/
    NSString *stricterFilterString = @"[A-Z0-9a-z\\._%+-]+@([A-Za-z0-9-]+\\.)+[A-Za-z]{2,4}";
    NSString *laxString = @".+@([A-Za-z0-9]+\\.)+[A-Za-z]{2}[A-Za-z]*";
    NSString *emailRegex = stricterFilter ? stricterFilterString : laxString;
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    return [emailTest evaluateWithObject:checkString];
}

- (bool)validateEmail {
    if( [self.emailTextFieldOutlet.text isEqualToString:@""] || ![self NSStringIsValidEmail:self.emailTextFieldOutlet.text] ) {
        // fail case
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Invalid Email Address",nil) message:NSLocalizedString(@"Please enter a valid email address, or hit cancel.",nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"OK",nil) otherButtonTitles:nil];
        [alert show];

        return NO;
    } else {
        
        BPPAppDelegate *appDelegate = (BPPAppDelegate *)[[UIApplication sharedApplication] delegate];
        [appDelegate addEmailAddress:self.emailTextFieldOutlet.text];
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Email Saved",nil) message:NSLocalizedString(@"Your email address has been saved, thank you!",nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"OK",nil) otherButtonTitles:nil];
        [alert show];
        
        self.emailTextFieldOutlet.text = @"";
        [self.view.window removeGestureRecognizer:_gestureRecognizer];
        [self dismissViewControllerAnimated:YES completion:nil];
        return YES;
    }
    

}

- (IBAction)OKButtonPressed:(id)sender {
    [self validateEmail];
}

- (IBAction)CancelButtonPressed:(id)sender {
    self.emailTextFieldOutlet.text = @"";
    [self.view.window removeGestureRecognizer:_gestureRecognizer];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField{
    if( [self validateEmail] ) {
        [textField resignFirstResponder];
        return YES;
    } else {
        return NO;
    }
}


@end
