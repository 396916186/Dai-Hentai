//
//  AppDelegate.h
//  e-Hentai
//
//  Created by 啟倫 陳 on 2014/8/27.
//  Copyright (c) 2014年 ChilunChen. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HentaiNavigationController.h"
#import "SliderViewController.h"
#import "PasswordViewController.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate, PasswordViewControllerDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UIWindow *realWindow;

@end
