//
//  PPWeakTimer.m
//  PPDNSMappingDemo
//
//  Created by gao feng on 16/1/19.
//  Copyright © 2016年 gao feng. All rights reserved.
//

#import "PPWeakTimer.h"

@interface PPWeakTimer()
@property (nonatomic, weak)     id              target;
@property (nonatomic, assign)   SEL             selector;
@property (nonatomic, weak)     NSTimer*        timer;
@end

@implementation PPWeakTimer

- (void)timerDidFire:(NSTimer *)timer {
    if(self.target)
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.target performSelector:self.selector withObject:timer.userInfo];
#pragma clang diagnostic pop
    }
    else {
        [self.timer invalidate];
    }
}

+ (NSTimer*)scheduledTimerWithTimeInterval:(NSTimeInterval)interval
                                      target:(id)aTarget
                                    selector:(SEL)aSelector
                                    userInfo:(id)userInfo
                                     repeats:(BOOL)repeats {
    PPWeakTimer* timerTarget = [[PPWeakTimer alloc] init];
    timerTarget.target = aTarget;
    timerTarget.selector = aSelector;
    timerTarget.timer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                         target:timerTarget
                                                       selector:@selector(timerDidFire:)
                                                       userInfo:userInfo
                                                        repeats:repeats];
    return timerTarget.timer;
}

@end
