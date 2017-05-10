//
//  ViewController.m
//  Example
//
//  Created by Maxwell on 2017/5/6.
//  Copyright © 2017年 Maxwell. All rights reserved.
//

#import "ViewController.h"
//#import <MSWebController/MSWebController.h>
#import <MSWebController/MSWebController.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        MSWebController *web = [[MSWebController alloc] init];
        web.useUIWebView = YES;
        [self presentViewController:[[UINavigationController alloc] initWithRootViewController:web] animated:YES completion:nil];
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
