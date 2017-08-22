//
//  LJAddShow.m
//  LJAddShow
//
//  Created by Jun on 2017/8/21.
//  Copyright © 2017年 Jun. All rights reserved.
//

#import "LJAddShow.h"

#import "LJAddWebViewController.h"

#import "LJDailyCache.h"

@interface LJAddShow()

@property (nonatomic, strong) UIWindow* window;

@property (nonatomic, assign) NSInteger downCount;

@property (nonatomic, weak) UIButton* downCountButton;

@property (nonatomic, assign) BOOL enterBackground;//检查是否是伪进入后台

@end

@implementation LJAddShow

//在load 方法中，启动监听，可以做到无侵入
+ (void)load {
    
    [self shareInstance];
}

+ (instancetype)shareInstance {
    
    static id instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    
    self = [super init];
    
    if (self) {
        
        //应用启动, 首次开屏广告
        [[NSNotificationCenter defaultCenter]
         addObserverForName:UIApplicationDidFinishLaunchingNotification
                     object:nil
                      queue:nil
                 usingBlock:^(NSNotification * _Nonnull note) {
            //要等DidFinished方法结束后才能初始化UIWindow，不然会检测是否有rootViewController
            
            self.enterBackground = YES;// 标志位初始化
            
            //检查是否满足条件显示广告
            [self checkAD];
        }];
        //进入后台
        [[NSNotificationCenter defaultCenter]
         addObserverForName:UIApplicationDidEnterBackgroundNotification
                     object:nil
                      queue:nil
                 usingBlock:^(NSNotification * _Nonnull note) {
            
            if (self.enterBackground) {
                
                // 请求新的广告数据
                [self requestADData];
            }
        }];
        //后台启动,二次开屏广告
        [[NSNotificationCenter defaultCenter]
         addObserverForName:UIApplicationWillEnterForegroundNotification
                     object:nil
                      queue:nil
                 usingBlock:^(NSNotification * _Nonnull note) {
            
            if (self.enterBackground) {
                
                //检查是否满足条件显示广告
                [self checkAD];
            }
            self.enterBackground = YES; // 标志位
        }];
        
        // 检测锁屏和解锁
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), //center
             NULL, // observer
             displayStatusChanged,
             CFSTR("com.apple.springboard.lockstate"),
             NULL, // object
             CFNotificationSuspensionBehaviorDeliverImmediately);
    }
    return self;
}

// 接受通知后的处理
static void displayStatusChanged(CFNotificationCenterRef center,
                                 void *observer,
                                 CFStringRef name,
                                 const void *object,
                                 CFDictionaryRef userInfo) {
    
    // 每次锁屏和解锁都会发这个通知，第一次是锁屏，第二次是解锁，交替进行  注：只有应用在前台锁、开屏才会走该通知  程序处于后台并不会走该通知（坑）
    [LJAddShow shareInstance].enterBackground = NO; // 标志位
}

#pragma mark --请求新的广告数据
- (void)requestADData {
    
}

#pragma mark --检测是否需要以及能够显示广告
- (void)checkAD {
    
    //这里进行次数判断，一般情况下这个次数可以做远程请求，不过为了方便做本地化处理，一天显示的广告的次数是有上限的，优化用户体验 并且也许判断用户切换时间是否足够长
    if ([[LJDailyCache shareInstance] judgeWhetherShowAd:[NSString stringWithFormat:@"%f",[[NSDate date]timeIntervalSince1970]]]) {
        
        [self show];
    }
}

- (void)show {
    
    //初始化一个Window， 做到对业务视图无干扰。
    UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    window.rootViewController = [UIViewController new];
    window.rootViewController.view.backgroundColor = [UIColor clearColor];
    window.rootViewController.view.userInteractionEnabled = NO;
    //广告布局
    [self setupSubviews:window];
    
    //设置为最顶层，防止 AlertView 等弹窗的覆盖
    window.windowLevel = UIWindowLevelStatusBar + 1;
    
    //默认为YES，当你设置为NO时，这个Window就会显示了
    window.hidden = NO;
    window.alpha = 1;
    
    ///防止释放，显示完后  要手动设置为 nil
    self.window = window;
}

- (void)letGo {
    
    //不直接取KeyWindow 是因为当有AlertView 或者有键盘弹出时， 取到的KeyWindow是错误的。
    UIViewController* rootVC = [[UIApplication sharedApplication].delegate window].rootViewController;
    [[rootVC imy_navigationController] pushViewController:[LJAddWebViewController new] animated:YES];
    
    [self hide];
}

- (void)goOut {
    
    [self hide];
}

- (void)hide {
    
    //来个渐显动画
    [UIView animateWithDuration:0.3 animations:^{
        self.window.alpha = 0;
    } completion:^(BOOL finished) {
        [self.window.subviews.copy enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [obj removeFromSuperview];
        }];
        self.window.hidden = YES;
        self.window = nil;
    }];
}

//初始化显示的视图， 可以挪到具
- (void)setupSubviews:(UIWindow*)window {
    
    //随便写写
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:window.bounds];
    imageView.image = [UIImage imageNamed:@"adimage.png"];
    imageView.userInteractionEnabled = YES;
    
    //给非UIControl的子类，增加点击事件
    UITapGestureRecognizer* tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(letGo)];
    [imageView addGestureRecognizer:tap];
    [window addSubview:imageView];
    
    //增加一个倒计时跳过按钮
    self.downCount = 3;
    
    UIButton * goout = [[UIButton alloc] initWithFrame:CGRectMake(window.bounds.size.width - 100 - 20, 20, 100, 60)];
    [goout setContentHorizontalAlignment:UIControlContentHorizontalAlignmentRight];
    [goout addTarget:self action:@selector(goOut) forControlEvents:UIControlEventTouchUpInside];
    [window addSubview:goout];
    
    self.downCountButton = goout;
    [self timer];
}

- (void)timer {
    
    [self.downCountButton setTitle:[NSString stringWithFormat:@"跳过：%ld",(long)self.downCount] forState:UIControlStateNormal];
    
    if (self.downCount <= 0) {
        
        [self hide];
    }else {
        
        self.downCount --;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self timer];
        });
    }
}

@end
