//
//  PPMappingUtil.m
//  PPDNSMappingDemo
//
//  Created by gao feng on 16/1/20.
//  Copyright © 2016年 gao feng. All rights reserved.
//

#import "PPMappingUtil.h"

@implementation PPMappingUtil

+ (NSString*)getUrlMappingKey:(NSURL*)url
{
    /** since we will be only modifying scheme, host, port. the key should be formatted like: scheme://host:port
     excluding path, parameter, query, fragament. **/
    
    NSString* port = @"";
    if (url.port != nil) {
        port = [NSString stringWithFormat:@":%d", url.port.intValue];
    }
    NSString* urlKey = [NSString stringWithFormat:@"%@://%@%@", url.scheme, url.host, port];
    
    return urlKey;
}

+ (BOOL)isIPAddress:(NSString*)address
{
    NSString  *urlRegEx =@"^([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\."
    "([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\."
    "([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\."
    "([01]?\\d\\d?|2[0-4]\\d|25[0-5])$";
    
    NSPredicate *urlTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", urlRegEx];
    return [urlTest evaluateWithObject:address];
}

@end
