//
//  PPDNSReporter.m
//  PPDNSMappingDemo
//
//  Created by gao feng on 16/1/19.
//  Copyright © 2016年 gao feng. All rights reserved.
//

#import "PPDNSReporter.h"

@implementation PPDNSReporter

+ (PPDNSReporter*)sharedInstance
{
    static PPDNSReporter* instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [PPDNSReporter new];
    });
    return instance;
}

- (void)reportFailedUrl:(NSString*)url withFailedCount:(int64_t)count
{
    NSLog(@"mapped url:%@ failed with count:%llu", url, count);
}

@end
