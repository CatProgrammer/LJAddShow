//
//  LJDailyCache.m
//  IMYADLaunchDemo
//自然日失效
//  Created by Jun on 2017/8/21.
//  Copyright © 2017年 Jun. All rights reserved.
//

#import "LJDailyCache.h"

static NSString *showTimes = @"20";// 其实是可以显示showTimes+1次 显示次数也可远程

static NSInteger  enterBackgroundTimeInterval = 10;// 进入后台时间间隔  时间太短也不可显示广告  这个可以远程请求

#define INTERVALTIME @"INTERVALTIME" // 间隔时间

@interface LJDailyCache()

@property (nonatomic, assign)BOOL   isShow; // 是否显示广告

@end

@implementation LJDailyCache

+ (instancetype)shareInstance {
    
    static id instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

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
        
        [self writeWithKey:key value:showTimes];
        
        self.isShow = YES;
    }
    
    // 判断时间间隔是否足够长
    if (self.isShow&&[time integerValue] - [intervalTime integerValue] > enterBackgroundTimeInterval) {
        
        self.isShow = YES;
        [self writeWithKey:INTERVALTIME value:time];
    }else {
        
        self.isShow = NO;
        [self writeWithKey:INTERVALTIME value:time];
    }
    
    
    return self.isShow;
}

#pragma mark --写入NSUserDefaults
- (void)writeWithKey:(NSString *)key value:(id)value {
    
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
}

#pragma mark --转化时间戳
- (NSString*)timeToTranslate:(NSNumber *)time Formatter:(NSString*)formatterStr {
    
    long long int date1 = (long long int)[time intValue];
    NSDate *date2 = [NSDate dateWithTimeIntervalSince1970:date1];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init] ;
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    [formatter setDateFormat:formatterStr];
    NSString *nowtimeStr = [formatter stringFromDate:date2];
    return nowtimeStr;
}

@end
