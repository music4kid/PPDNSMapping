//
//  PPDNSMappingManager.h
//  PPDNSMappingDemo
//
//  Created by gao feng on 16/1/19.
//  Copyright © 2016年 gao feng. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PPResolvedUrl;

#define Notif_DomainRequestResult        @"Notif_DomainRequestResult" //result from application layer
#define Notif_IPValidateResult           @"Notif_IPValidateResult" //result from ipvalidator

@interface PPDNSMappingManager : NSObject

@property (nonatomic, strong) NSString*                 diskSavePath;

+ (instancetype)sharedInstance;

//local file with default mapping
- (void)setDefaultLocalMapping:(NSString*)filePath;

//read mapping from previous server response
- (void)readMappingFromDisk;

//interval should be larger than 3s
- (void)startSyncTimerWithInterval:(NSTimeInterval)interval withSrcUrl:(NSString*)srcUrl;

//resolve url
- (PPResolvedUrl*)resolveUrl:(NSURL*)originalUrl;

@end
