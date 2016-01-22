//
//  PPIPValidator.h
//  PPDNSMappingDemo
//
//  Created by gao feng on 16/1/19.
//  Copyright © 2016年 gao feng. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PPIPValidator : NSObject

+ (instancetype)sharedInstance;

- (void)validateIP:(NSString*)ip;

@end
