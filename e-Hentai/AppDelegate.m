//
//  AppDelegate.m
//  e-Hentai
//
//  Created by 啟倫 陳 on 2014/8/27.
//  Copyright (c) 2014年 ChilunChen. All rights reserved.
//

#import "AppDelegate.h"

#import "AppDelegate+SupportKit.h"

@implementation AppDelegate

#pragma mark - PasswordViewControllerDelegate

- (void)onPassed {
    if (self.realWindow) {
        [self.realWindow makeKeyAndVisible];
    }
    else {
        self.realWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        HentaiNavigationController *hentaiNavigation = [[HentaiNavigationController alloc] initWithRootViewController:[SliderViewController new]];
        hentaiNavigation.autoRotate = NO;
        hentaiNavigation.hentaiMask = UIInterfaceOrientationMaskPortrait;
        self.realWindow.rootViewController = hentaiNavigation;
        [self.realWindow makeKeyAndVisible];
    }
}

#pragma mark - app life cycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    //設定 hud 的基本參數
    [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeClear];
    
    //supportkit
    [self setupSupportKit];
    
    //Flurry
    [Flurry setCrashReportingEnabled:YES];
    [Flurry startSession:@"BY5JD5CPV7N4C3R2CP2J"];
    
    //轉移
    [self oldDataChecking];
    
    //display
    application.statusBarOrientation = UIDeviceOrientationPortrait;
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    PasswordViewController *passwordViewController = [PasswordViewController new];
    passwordViewController.delegate = self;
    self.window.rootViewController = passwordViewController;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    [self.window makeKeyAndVisible];
}

- (void)oldDataChecking {
    
    //舊的儲存方式搬移
    if ([[FilesManager documentFolder] read:@"HentaiCacheLibrary.plist"].length || [[FilesManager documentFolder] read:@"HentaiSaveLibrary.plist"].length) {
        @weakify(self);
        [UIAlertView hentai_alertViewWithTitle:@"注意~ O3O" message:@"因為改變儲存方式, 現在要幫你搬資料" cancelButtonTitle:@"沒有取消~ O3<" otherButtonTitles:@[@"好~ >3O"] onClickIndex:^(NSInteger clickIndex) {
            @strongify(self);
            [self dataTransfer];
        } onCancel:^{
            @strongify(self);
            [self dataTransfer];
        }];
    }
    
    //舊的設定值搬移
    [HentaiSettingManager settingTransfer];
}

- (void)dataTransfer {
    [SVProgressHUD show];
    NSArray *saveDatas = LWPArray(@"HentaiSaveLibrary");
    for (NSDictionary *eachData in saveDatas) {
        [HentaiSaveLibrary addSaveInfo:eachData toGroup:@""];
    }
    LWPDelete(@"HentaiSaveLibrary");
    
    NSDictionary *cacheDatas = LWPDictionary(@"HentaiCacheLibrary");
    for (NSString *eachKey in [cacheDatas allKeys]) {
        [HentaiCacheLibrary addCacheInfo:cacheDatas[eachKey] forKey:eachKey];
    }
    LWPDelete(@"HentaiCacheLibrary");
    [SVProgressHUD dismiss];
}

@end
