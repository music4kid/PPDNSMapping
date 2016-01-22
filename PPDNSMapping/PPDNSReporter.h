//
//  PPDNSReporter.h
//  PPDNSMappingDemo
//
//  Created by gao feng on 16/1/19.
//  Copyright © 2016年 gao feng. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PPDNSReporter : NSObject

+ (PPDNSReporter*)sharedInstance;

- (void)reportFailedUrl:(NSString*)url withFailedCount:(int64_t)count;

@end
