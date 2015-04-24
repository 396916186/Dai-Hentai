//
//  HentaiDownloadCenter.m
//  e-Hentai
//
//  Created by 啟倫 陳 on 2014/9/11.
//  Copyright (c) 2014年 ChilunChen. All rights reserved.
//

#import "HentaiDownloadCenter.h"

#import <objc/runtime.h>

#define waitingQueue [self waitingAddressQueue]
#define downloadingQueue [self downloadingAddressQueue]

@interface WeakOperationContainer : NSObject

@property (nonatomic, weak) HentaiDownloadBookOperation *weakOperation;

@end

@implementation WeakOperationContainer

- (id)initWithOperation:(HentaiDownloadBookOperation *)operation {
    self = [super init];
    if (self) {
        self.weakOperation = operation;
    }
    return self;
}

@end

@implementation HentaiDownloadCenter

#pragma mark - HentaiDownloadBookOperationDelegate

//用來回報 download center 的狀態
+ (void)hentaiDownloadBookOperationChange:(HentaiDownloadBookOperation *)operation {
    //center 本身需要掌握目前 operations 的活動, 因此這個部分不管 block 在不在都要做
    [self operationActivity:operation];
    
    //然後刷新 monitor
    [self refreshMonitor];
}

#pragma mark - class method

+ (void)addBook:(NSDictionary *)hentaiInfo toGroup:(NSString *)group {
    
    //下載過的話不給下
    BOOL isExist = ([HentaiSaveLibrary saveInfoAtHentaiKey:[hentaiInfo hentai_hentaiKey]])?YES:NO;
    
    //如果在 queue 裡面也不給下
    isExist = isExist | [self isDownloading:hentaiInfo];
    
    if (isExist) {
        [JDStatusBarNotification showWithStatus:@"你可能已經下載過或是正在下載中!" dismissAfter:2.0f styleName:JDStatusBarStyleWarning];
    }
    else {
        HentaiDownloadBookOperation *newOperation = [HentaiDownloadBookOperation new];
        newOperation.delegate = (id <HentaiDownloadBookOperationDelegate> )self;
        newOperation.hentaiInfo = hentaiInfo;
        newOperation.group = group;
        newOperation.status = HentaiDownloadBookOperationStatusWaiting;
        [self operationActivity:newOperation];
        [[self allBooksOperationQueue] addOperation:newOperation];
    }
}

+ (BOOL)isDownloading:(NSDictionary *)hentaiInfo {
    BOOL isExist = NO;
    
    for (HentaiDownloadBookOperation *eachOperation in[[self allBooksOperationQueue] operations]) {
        if ([[eachOperation.hentaiInfo hentai_hentaiKey] isEqualToString:[hentaiInfo hentai_hentaiKey]]) {
            isExist = YES;
            break;
        }
    }
    return isExist;
}

+ (BOOL)isActiveFolder:(NSString *)folder {
    BOOL isExist = NO;
    for (HentaiDownloadBookOperation *eachOperation in[[self allBooksOperationQueue] operations]) {
        NSString *hentaiKey = [eachOperation.hentaiInfo hentai_hentaiKey];

        //有時候不一定會完全 equal, 所以用 range 來做
        if ([hentaiKey rangeOfString:folder].location != NSNotFound) {
            isExist = YES;
            break;
        }
    }
    return isExist;
}

+ (void)centerMonitor:(HentaiMonitorBlock)monitor {
    [self setMonitor:monitor];
    
    //先刷一次才知道目前的狀態
    [self refreshMonitor];
}

#pragma mark - private

//刷新給監控方看的資料內容
+ (void)refreshMonitor {
    HentaiMonitorBlock monitor = [self monitor];
    if (monitor) {
        NSMutableArray *waitingItems = [NSMutableArray array];
        NSMutableArray *downloadingItems = [NSMutableArray array];
        
        [self cleanNilOperationInQueue:waitingQueue];
        [self cleanNilOperationInQueue:downloadingQueue];
        
        for (WeakOperationContainer *eachWeakOperationContainer in waitingQueue) {
            if (eachWeakOperationContainer.weakOperation) {
                [waitingItems addObject:@{ @"hentaiInfo":eachWeakOperationContainer.weakOperation.hentaiInfo }];
            }
        }
        
        for (WeakOperationContainer *eachWeakOperationContainer in downloadingQueue) {
            if (eachWeakOperationContainer.weakOperation) {
                [downloadingItems addObject:@{ @"hentaiInfo":eachWeakOperationContainer.weakOperation.hentaiInfo, @"recvCount":@(eachWeakOperationContainer.weakOperation.recvCount), @"totalCount":@(eachWeakOperationContainer.weakOperation.totalCount) }];;
            }
        }
        monitor(@{ @"waitingItems":waitingItems, @"downloadingItems":downloadingItems });
    }
}

//如果有人是 nil 了, 把他們移除掉
+ (void)cleanNilOperationInQueue:(NSMutableArray *)queue {
    NSMutableArray *removeItems = [NSMutableArray array];
    for (WeakOperationContainer *eachWeakOperationContainer in queue) {
        if (eachWeakOperationContainer.weakOperation == nil) {
            [removeItems addObject:eachWeakOperationContainer];
        }
    }
    [queue removeObjectsInArray:removeItems];
}

//找看某個 address 是否在 queue 裡面
+ (NSInteger)findOperation:(NSOperation *)operation inQueue:(NSMutableArray *)queue {
    NSInteger addressAtIndex = NSNotFound;
    for (WeakOperationContainer *eachWeakOperationContainer in queue) {
        if (eachWeakOperationContainer.weakOperation == operation) {
            addressAtIndex = [queue indexOfObject:eachWeakOperationContainer];
            break;
        }
    }
    return addressAtIndex;
}

//記錄 operation 活動狀態
+ (void)operationActivity:(HentaiDownloadBookOperation *)operation {
    if (operation) {
        //NSString *operationAddressString = [NSString stringWithFormat:@"%p", operation];
        WeakOperationContainer *weakOperation = [[WeakOperationContainer alloc] initWithOperation:operation];
        
        switch (operation.status) {
                //會進 waiting 有兩個原因, 一是數值 init, 另一則是數值確實到 waiting 了
            case HentaiDownloadBookOperationStatusWaiting:
            {
                NSInteger waitingIndex = [self findOperation:operation inQueue:waitingQueue];
                
                //如果找不到這個 address, 就把他存起來
                if (waitingIndex == NSNotFound) {
                    [waitingQueue addObject:weakOperation];
                }
                break;
            }
                
                //會進 downloading 有兩個原因, 一是由 waiting 轉為 downloading, 另一則是 download 中間 count 的變化
            case HentaiDownloadBookOperationStatusDownloading:
            {
                NSInteger waitingIndex = [self findOperation:operation inQueue:waitingQueue];
                
                //如果 waiting queue 裡面有他, 把他從 waiting queue 裡面移除, 新增到 downloading queue
                if (waitingIndex != NSNotFound) {
                    [waitingQueue removeObjectAtIndex:waitingIndex];
                    [downloadingQueue addObject:weakOperation];
                }
                break;
            }
                
                //下載完的時候就把他從 download queue 移除
            case HentaiDownloadBookOperationStatusFinished:
            {
                NSInteger downloadingIndex = [self findOperation:operation inQueue:downloadingQueue];
                
                //如果 download queue 裡面有他, 把他移除掉
                if (downloadingIndex != NSNotFound) {
                    [downloadingQueue removeObjectAtIndex:downloadingIndex];
                }
                break;
            }
        }
    }
}

#pragma mark - runtime objects

+ (NSOperationQueue *)allBooksOperationQueue {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSOperationQueue *hentaiQueue = [NSOperationQueue new];
        [hentaiQueue setMaxConcurrentOperationCount:2];
        objc_setAssociatedObject(self, _cmd, hentaiQueue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    });
    return objc_getAssociatedObject(self, _cmd);
}

+ (void)setMonitor:(HentaiMonitorBlock)monitor {
    objc_setAssociatedObject(self, @selector(monitor), monitor, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

+ (HentaiMonitorBlock)monitor {
    return objc_getAssociatedObject(self, _cmd);
}

+ (NSMutableArray *)waitingAddressQueue {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        objc_setAssociatedObject(self, _cmd, [NSMutableArray array], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    });
    return objc_getAssociatedObject(self, _cmd);
}

+ (NSMutableArray *)downloadingAddressQueue {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        objc_setAssociatedObject(self, _cmd, [NSMutableArray array], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    });
    return objc_getAssociatedObject(self, _cmd);
}

@end
