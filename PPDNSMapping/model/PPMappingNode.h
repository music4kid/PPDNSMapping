//
//  PPMappingNode.h
//  PPDNSMappingDemo
//
//  Created by gao feng on 16/1/21.
//  Copyright © 2016年 gao feng. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PPMappingNode : NSObject

@property (nonatomic, strong) NSString*                 mappedUrl; //ip or domain
@property (nonatomic, assign) int                       requestFailedCount;

@end
