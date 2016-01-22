//
//  PPDomainRequestResult.h
//  PPDNSMappingDemo
//
//  Created by gao feng on 16/1/19.
//  Copyright © 2016年 gao feng. All rights reserved.
//

/**
application layer module use this model to tell mapping engine, whether mapped url is healthy or not.
**/

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    PPDomainRequestSuccess = 0,
    PPDomainRequestFail,
} PPDomainRequestResultStatus;

@interface PPDomainRequestResult : NSObject

@property (nonatomic, strong) NSURL*                                        resultUrl;
@property (nonatomic, assign) PPDomainRequestResultStatus                   status;

@end
