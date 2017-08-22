# LJAddShow
>写在前面：项目最近一个需求增加开屏广告，本着偷懒的打算（不想过多的改变之前的代码，毕竟bug是改出来的）而又恰巧之前在网上看到过[一个不知名大神](http://www.cocoachina.com/ios/20160628/16828.html)和[bestswifter](http://www.jianshu.com/p/d5e42fd92484)写过关于无侵入广告设计思想，结合项目实际情况做了这个即插即用的开屏广告小功能。


## 需要实现的效果
显示场景我总结为：点击App初次启动、App进入后台再返回前台。当然深层次考虑用户友好度问题，就要分析切换前后台间隔时间问题、广告每日显示次数的上限问题等。在这个地方有一个难点，就是准确的抓住用户的进入后台行为，因为我们是调用苹果的API，这里面有一些小坑会导致我们抓取到了一些伪进入后台的操作，在下面具体实现我用代码解释。

## 核心点
这个涉及到NSObject的load方法的运行机制，凡是重写了load方法的类系统都会在didFinishLaunchingWithOptions运行之前自动调用一次该方法.[有篇帖子就是解释这个的](http://www.jianshu.com/p/db49787886eb)
```
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
         // 写一些通知和核心逻辑代码
    }
    return self;
}
```
## 抓取进入后台的行为
类似我之前说的，我们是调用苹果的API监听**UIApplicationDidFinishLaunchingNotification**、**UIApplicationDidEnterBackgroundNotification**、**UIApplicationWillEnterForegroundNotification**这三个状态。
但是这里有个问题，就是当你应用在前台锁屏的情况下，它一样会发送**UIApplicationDidEnterBackgroundNotification**（进入后台）的通知。这就是我上面说的伪进入后台的情况。所以在这里我用**CFNotificationCenterAddObserver**监听锁屏和开屏的状态，并设立一个标志位**self.enterBackground**来判断是否是真的进入后台的操作以及是否需要显示广告，这个标志位的逻辑处理，我测试的好久没啥问题，理解上有点难理解，大概的意思就是检测出App处于前台而你锁屏了这一动作，将其从排除掉。
```
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
```
## 优化业务--广告显示次数上限以及进入后台间隔时间
假如存在用户快速的切换App前后台，或者用户一天内多次启动App。我们是否应该继续让用户将时间耗费在这个烦人的广告上。从用户友好度上来考虑，我们应对App做一些逻辑调整。所以这里我们可以单独抽出一个自然日缓存类**#import "LJDailyCache.h"** 
这一段代码其实没什么难度，主要是个细心吧。将年月日作为key值存储App的在该日还可显示的广告次数，把握好真实进入后台和进入前台的动作记录这两个的时间点。里面的自然日显示次数上限以及进入后台的时间间隔都可以通过远程请求，万一对广告有什么别的业务调整会方便一点。
```
static NSString *showTimes = @"20";//  显示次数也可远程

static NSInteger  enterBackgroundTimeInterval = 10;// 进入后台时间间隔  时间太短也不可显示广告  这个可以远程请求

@property (nonatomic, assign)BOOL   isShow; // 是否显示广告 标志位

#pragma mark --判断是否符合条件显示广告  今天是否剩余显示次数  是否间隔足够时间
- (BOOL)judgeWhetherShowAd:(NSString *)time {
    
    // 获取今天的日期 格式“2017-08-12”作为存储广告显示次数的key
    NSString *key = [self timeToTranslate:[NSNumber numberWithFloat:[[NSDate date]timeIntervalSince1970]] Formatter:@"yyyy-MM-dd"];
    
    
    NSString *adTime = [[NSUserDefaults standardUserDefaults] stringForKey:key];
    
    NSString *intervalTime = [[NSUserDefaults standardUserDefaults] stringForKey:INTERVALTIME];
    
    // 查看是否存在今天的广告次数
    if (adTime) {
        
        if ([adTime integerValue] > 0) {
            
            [self writeWithKey:key value:[NSString stringWithFormat:@"%ld",[adTime integerValue] - 1]];

            self.isShow = YES;
        }else {
            
            self.isShow = NO;
        }
    }else {
        
        [self writeWithKey:key value:showTime];
        
        self.isShow = YES;
    }
    
    // 判断时间间隔是否足够长
    if (self.isShow&&[time integerValue] - [intervalTime integerValue] > appTimeInterval) {
        
        self.isShow = YES;
        [self writeWithKey:INTERVALTIME value:time];
    }else {
        
        self.isShow = NO;
        [self writeWithKey:INTERVALTIME value:time];
    }
    
    
    return self.isShow;
}
```
这个Demo里有一段关于广告VC显示的代码我感觉很好 **这段代码跟我没关系**
这样写的好处是，让视图出现在最顶层，避免了其他的业务代码的覆盖干扰。
```
- (void)show
{   
    ///初始化一个Window， 做到对业务视图无干扰。
    UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];  
    ///广告布局
    [self setupSubviews:window];   
    ///设置为最顶层，防止 AlertView 等弹窗的覆盖
    window.windowLevel = UIWindowLevelStatusBar + 1;    
    ///默认为YES，当你设置为NO时，这个Window就会显示了
    window.hidden = NO;    
    ///来个渐显动画
    window.alpha = 0;
    [UIView animateWithDuration:0.3 animations:^{
        window.alpha = 1;
    }];    
    ///防止释放，显示完后  要手动设置为 nil
    self.window = window;
}
```
## 使用
①将Demo里的**LJAddShow**文件夹拖入到工程里；
②**LJAddShow.h**文件里**- (void)show**方法处理需要显示的广告数据；
③**LJDailyCache.h**文件里修改两个局部变量 **showTimes**（每日显示上限次数）和**enterBackgroundTimeInterval**（进入后台间隔时间）；
④**LJAddWebViewController.h**广告页，一般是自己工程的web页面。
就这样不需要改变之前的代码，一个开屏广告功能完成。

## 总结
该功能主要涉及到NSObject的load方法运用、App状态变化的抓取以及一些小的逻辑梳理，细心一点就好。
