//
//  PPWeakTimer.h
//  PPDNSMappingDemo
//
//  Created by gao feng on 16/1/19.
//  Copyright © 2016年 gao feng. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^PPTimerHandler)(id userInfo);

@interface PPWeakTimer : NSObject

+ (NSTimer*)scheduledTimerWithTimeInterval:(NSTimeInterval)interval
                                      target:(id)aTarget
                                    selector:(SEL)aSelector
                                    userInfo:(id)userInfo
                                     repeats:(BOOL)repeats;

@end
