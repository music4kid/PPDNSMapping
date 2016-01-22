//
//  ViewController.m
//  PPDNSMappingDemo
//
//  Created by gao feng on 16/1/19.
//  Copyright © 2016年 gao feng. All rights reserved.
//

#import "ViewController.h"
#import "PPDNSMapping.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    __block NSString* mapping1;
    __block NSString* mapping2;
    __block NSString* mapping3;
    
    NSString* filePath = [[NSBundle mainBundle] pathForResource:@"defaultMapping" ofType:@"txt"];
    [[PPDNSMappingManager sharedInstance] setDefaultLocalMapping:filePath];
    
//    [[PPDNSMappingManager sharedInstance] readMappingFromDisk];
    
    //test mapping sync
//    NSString* syncUrl = @"https://10.43.111.25/testapp/mapping";
//    [[PPDNSMappingManager sharedInstance] startSyncTimerWithInterval:5 withSrcUrl:syncUrl];
    
    //do mapping
    NSString* testUrl = @"http://avatar.testapp.com:80/test;params?a=b#fragment";
    PPResolvedUrl* resolved = [[PPDNSMappingManager sharedInstance] resolveUrl:[NSURL URLWithString:testUrl]];
    NSLog(@"resolved url:%@ host:%@", resolved.resolvedUrl, resolved.resolvedHost);
    mapping1 = resolved.resolvedUrl;
    NSAssert(mapping1 != nil, @"valid mapping expected");
    
    //simulate request fail
    PPDomainRequestResult* result = [PPDomainRequestResult new];
    result.resultUrl = [NSURL URLWithString:resolved.resolvedUrl];
    result.status = PPDomainRequestFail;
    [[NSNotificationCenter defaultCenter] postNotificationName:Notif_DomainRequestResult object:result];
    
    //try mapping in 1 seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        PPResolvedUrl* resolved = [[PPDNSMappingManager sharedInstance] resolveUrl:[NSURL URLWithString:testUrl]];
        NSLog(@"resolved url again:%@ host:%@", resolved.resolvedUrl, resolved.resolvedHost);
        mapping2 = resolved.resolvedUrl;
        
        NSAssert([mapping1 isEqualToString:mapping2] == false, @"different mapping expected.");
        
        
        //simulate request fail again
        PPDomainRequestResult* result = [PPDomainRequestResult new];
        result.resultUrl = [NSURL URLWithString:resolved.resolvedUrl];
        result.status = PPDomainRequestFail;
        [[NSNotificationCenter defaultCenter] postNotificationName:Notif_DomainRequestResult object:result];
        
        
        //try mapping in 1 seconds
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            PPResolvedUrl* resolved = [[PPDNSMappingManager sharedInstance] resolveUrl:[NSURL URLWithString:testUrl]];
            NSLog(@"resolved url again:%@ host:%@", resolved.resolvedUrl, resolved.resolvedHost);
            mapping3 = resolved.resolvedUrl;
            
            NSAssert([mapping3 isEqualToString:testUrl], @"no mapping expected.");
        });
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
