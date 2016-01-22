//
//  PPMappingUtil.h
//  PPDNSMappingDemo
//
//  Created by gao feng on 16/1/20.
//  Copyright © 2016年 gao feng. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PPMappingUtil : NSObject

+ (NSString*)getUrlMappingKey:(NSURL*)url;

+ (BOOL)isIPAddress:(NSString*)address;

@end
