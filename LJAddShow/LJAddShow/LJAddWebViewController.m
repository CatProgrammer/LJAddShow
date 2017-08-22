//
//  LJAddWebViewController.m
//  LJAddShow
//广告页
//  Created by Jun on 2017/8/21.
//  Copyright © 2017年 Jun. All rights reserved.
//

#import "LJAddWebViewController.h"

#import <WebKit/WebKit.h>

@interface LJAddWebViewController ()

@property (nonatomic, strong)WKWebView  *webView;

@end

@implementation LJAddWebViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.title = @"我是广告";
    self.webView = [[WKWebView alloc] initWithFrame:self.view.bounds];
    self.webView.backgroundColor = [UIColor whiteColor];
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.jianshu.com/u/91b96851bfdf"]]];
    [self.view addSubview:self.webView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

@implementation UIViewController (IMYPublic)

- (UINavigationController*)imy_navigationController
{
    UINavigationController* nav = nil;
    if ([self isKindOfClass:[UINavigationController class]]) {
        nav = (id)self;
    }
    else {
        if ([self isKindOfClass:[UITabBarController class]]) {
            nav = [((UITabBarController*)self).selectedViewController imy_navigationController];
        }
        else {
            nav = self.navigationController;
        }
    }
    return nav;
}

@end
