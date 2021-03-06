//
//  BPPAppDelegate.m
//  PhotoPad
//
//  Created by Albert Martin on 11/20/13.
//  Copyright (c) 2013 Albert Martin. All rights reserved.
//

#import "BPPAppDelegate.h"
#import "BPPEyeFiConnector.h"
#import "BPPAirprintCollagePrinter.h"

#import "HTTPServer.h"

@interface BPPAppDelegate() {
    NSString* _emailFilePath;
    NSMutableArray* _emailAddresses;
}
@end

@implementation BPPAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
    // where email addresses will be read/written
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	_emailFilePath = [documentsDirectory stringByAppendingPathComponent:@"emailaddresses.txt"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
	if( [fileManager fileExistsAtPath:_emailFilePath] ) {
        
        NSString* existingEmailAddresses = [NSString stringWithContentsOfFile:_emailFilePath encoding:NSUTF8StringEncoding error:nil];

        _emailAddresses = [[existingEmailAddresses componentsSeparatedByString:@"\n"] mutableCopy];
        
        // remove empty lines
        for( int i=0 ; i < _emailAddresses.count ; i++ ) {
            if( [_emailAddresses[i] isEqualToString:@""] )
                [_emailAddresses removeObjectAtIndex:i];
        }
        
        NSLog(@"%lu existing email addresses: %@", (unsigned long)_emailAddresses.count, existingEmailAddresses);
    } else {
        NSLog(@"No existing email addresses on disk");
        _emailAddresses = [NSMutableArray array];
    }
    
    // Initalize our http server
	_httpServer = [[HTTPServer alloc] init];
	[_httpServer setConnectionClass:[BPPEyeFiConnector class]];
    [_httpServer setType:@"_http._tcp."];
	[_httpServer setPort:59278];
    [_httpServer start:nil];
    
    // Register for EyeFi communication notifications.
    _overlay = [MTStatusBarOverlay sharedInstance];
    _overlay.animation = MTStatusBarOverlayAnimationNone;
    _overlay.delegate = self;
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(updateEyeFiStatus:)
                                                name:@"EyeFiCommunication"
                                              object:nil];

    return YES;
}

- (void)updateEyeFiStatus:(NSNotification *)notification
{
    NSLog(@"%@", [notification.userInfo objectForKey:@"method"]);
    
    if ([[notification.userInfo objectForKey:@"method"] isEqualToString:@"GalleryUpdated"]) {
        [_overlay postFinishMessage:@"New Photo Added" duration:5];
        return;
    }
    
    if ([[notification.userInfo objectForKey:@"method"] isEqualToString:@"MarkLastPhotoInRoll"]) {
        [_overlay postMessage:@"Uncompressing Photo"];
    } else {
        [_overlay postMessage:@"Copying New Photo"];
    }
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)writeEmailAddresses {
    
    @synchronized( _emailAddresses ) {
        
        NSData* data = [[self getStringOfAllEmailAddresses] dataUsingEncoding:NSUTF8StringEncoding];
        [data writeToFile:_emailFilePath atomically:YES];
    }
}

- (void)addEmailAddress:(NSString*)email {
    @synchronized( _emailAddresses ) {
        [_emailAddresses addObject:email];
        [self writeEmailAddresses];
    }
}

- (NSString*)getStringOfAllEmailAddresses {
    NSString* bigString = @"";

    @synchronized( _emailAddresses ) {
        
        for( id str in _emailAddresses ) {
            bigString = [bigString stringByAppendingString:str];
            bigString = [bigString stringByAppendingString:@"\n"];
        }
        
        return bigString;
    }
}


@end
