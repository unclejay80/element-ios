/*
 Copyright 2015 OpenMarket Ltd
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#define RAGESHAKEMANAGER_MINIMUM_SHAKING_DURATION 2

#import "RageShakeManager.h"

#import "AppDelegate.h"
#import "BugReportViewController.h"

#import "NSBundle+MatrixKit.h"

static RageShakeManager* sharedInstance = nil;

@interface RageShakeManager() {
    bool isShaking;
    double startShakingTimeStamp;
    
    MXKAlert *confirmationAlert;
}
@end

@implementation RageShakeManager

#pragma mark Singleton Method

+ (id)sharedManager {
    @synchronized(self) {
        if(sharedInstance == nil)
            sharedInstance = [[self alloc] init];
    }
    return sharedInstance;
}

#pragma mark -

- (instancetype)init {
    
    self = [super init];
    if (self) {
        isShaking = NO;
        startShakingTimeStamp = 0;

        confirmationAlert = nil;

    }
    
    return self;
}

- (void)promptCrashReportInViewController:(UIViewController*)viewController {
    if ([MXLogger crashLog] && [MFMailComposeViewController canSendMail]) {
        
        confirmationAlert = [[MXKAlert alloc] initWithTitle:NSLocalizedStringFromTable(@"bug_report_prompt", @"Vector", nil)  message:nil style:MXKAlertStyleAlert];
        
        __weak typeof(self) weakSelf = self;
        [confirmationAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
            typeof(self) self = weakSelf;
            self->confirmationAlert = nil;
            
            // Erase the crash log (there is only chance for the user to send it)
            [MXLogger deleteCrashLog];
        }];
        
        [confirmationAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
            typeof(self) self = weakSelf;
            self->confirmationAlert = nil;

            BugReportViewController *bugReportViewController = [BugReportViewController bugReportViewController];
            bugReportViewController.reportCrash = YES;
            [bugReportViewController showInViewController:viewController];
        }];
        
        [confirmationAlert showInViewController:viewController];
    }
}

#pragma mark - MXKResponderRageShaking

- (void)startShaking:(UIResponder*)responder {
    
    // Start only if the application is in foreground
    if ([AppDelegate theDelegate].isAppForeground && !confirmationAlert) {
        NSLog(@"[RageShakeManager] Start shaking with [%@]", [responder class]);
        
        startShakingTimeStamp = [[NSDate date] timeIntervalSince1970];
        isShaking = YES;
    }
}

- (void)stopShaking:(UIResponder*)responder {
    
    NSLog(@"[RageShakeManager] Stop shaking with [%@]", [responder class]);
    
    if (isShaking && [AppDelegate theDelegate].isAppForeground && !confirmationAlert
        && (([[NSDate date] timeIntervalSince1970] - startShakingTimeStamp) > RAGESHAKEMANAGER_MINIMUM_SHAKING_DURATION)) {
        
        if ([responder isKindOfClass:[UIViewController class]] && [MFMailComposeViewController canSendMail]) {
            confirmationAlert = [[MXKAlert alloc] initWithTitle:NSLocalizedStringFromTable(@"rage_shake_prompt", @"Vector", nil)  message:nil style:MXKAlertStyleAlert];
            
            __weak typeof(self) weakSelf = self;
            [confirmationAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                typeof(self) self = weakSelf;
                self->confirmationAlert = nil;
            }];
            
            [confirmationAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                typeof(self) self = weakSelf;
                self->confirmationAlert = nil;

                UIViewController *controller = (UIViewController*)responder;
                if (controller) {

                    BugReportViewController *bugReportViewController = [BugReportViewController bugReportViewController];
                    bugReportViewController.screenshot = [self takeScreenshot];
                    [bugReportViewController showInViewController:controller];
                }
            }];
            
            [confirmationAlert showInViewController:(UIViewController*)responder];
        }
    }
    
    isShaking = NO;
}

- (void)cancel:(UIResponder*)responder {
    
    isShaking = NO;
}

/**
  Take a screenshot of the current screen.

 @return an image
 */
- (UIImage*)takeScreenshot {

    UIImage *image;

    AppDelegate* theDelegate = [AppDelegate theDelegate];
    UIGraphicsBeginImageContextWithOptions(theDelegate.window.bounds.size, NO, [UIScreen mainScreen].scale);

    // Iterate over every window from back to front
    for (UIWindow *window in [[UIApplication sharedApplication] windows])
    {
        if (![window respondsToSelector:@selector(screen)] || [window screen] == [UIScreen mainScreen])
        {
            // -renderInContext: renders in the coordinate space of the layer,
            // so we must first apply the layer's geometry to the graphics context
            CGContextSaveGState(UIGraphicsGetCurrentContext());
            // Center the context around the window's anchor point
            CGContextTranslateCTM(UIGraphicsGetCurrentContext(), [window center].x, [window center].y);
            // Apply the window's transform about the anchor point
            CGContextConcatCTM(UIGraphicsGetCurrentContext(), [window transform]);
            // Offset by the portion of the bounds left of and above the anchor point
            CGContextTranslateCTM(UIGraphicsGetCurrentContext(),
                                  -[window bounds].size.width * [[window layer] anchorPoint].x,
                                  -[window bounds].size.height * [[window layer] anchorPoint].y);

            // Render the layer hierarchy to the current context
            [[window layer] renderInContext:UIGraphicsGetCurrentContext()];

            // Restore the context
            CGContextRestoreGState(UIGraphicsGetCurrentContext());
        }
    }
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    // the image is copied in the clipboard
    [UIPasteboard generalPasteboard].image = image;

    return image;
}

@end