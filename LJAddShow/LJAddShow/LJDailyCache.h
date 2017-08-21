//
//  LJDailyCache.h
//  IMYADLaunchDemo
//
//  Created by 李军 on 2017/8/21.
//  Copyright © 2017年 ljh. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LJDailyCache : NSObject

+ (instancetype)shareInstance;

/**
 传入时间判断是否能够显示广告

 @param time 当前时间
 @return 是否可以显示广告
 */
- (BOOL)judgeWhetherShowAd:(NSString *)time;

/**
 往NSUserDefaults里写数据

 @param key <#key description#>
 @param value <#value description#>
 */
- (void)writeWithKey:(NSString *)key value:(id)value;

@end
