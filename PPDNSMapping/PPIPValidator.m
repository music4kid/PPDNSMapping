//
//  PPIPValidator.m
//  PPDNSMappingDemo
//
//  Created by gao feng on 16/1/19.
//  Copyright © 2016年 gao feng. All rights reserved.
//

#import "PPIPValidator.h"
#import "PPDNSMappingManager.h"
#import "PPDomainRequestResult.h"

#define kMaxValidateRetry   10
#define kValidateInterval   3

@interface PPValidatingNode : NSObject
@property (nonatomic, strong) NSString*                 url;
@property (nonatomic, assign) int                       failedCount;
@end
@implementation PPValidatingNode
@end


@interface PPIPValidator ()
@property (nonatomic, strong) NSMutableDictionary*                 validatingMap;
@end

@implementation PPIPValidator
{
    dispatch_semaphore_t _sema;
}

+ (instancetype)sharedInstance
{
    static PPIPValidator* instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [PPIPValidator new];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _sema = dispatch_semaphore_create(1);
        
        self.validatingMap = @{}.mutableCopy;
    }
    return self;
}

- (void)validateIP:(NSString*)ipUrl
{
    @synchronized(self)
    {
        dispatch_semaphore_wait(_sema, DISPATCH_TIME_FOREVER);
        PPValidatingNode* node = [self.validatingMap objectForKey:ipUrl];
        dispatch_semaphore_signal(_sema);
        
        if (!node) {
            node = [PPValidatingNode new];
            node.url = ipUrl;
            node.failedCount = 1;
            
            dispatch_semaphore_wait(_sema, DISPATCH_TIME_FOREVER);
            [self.validatingMap setObject:node forKey:ipUrl];
            dispatch_semaphore_signal(_sema);
            
            //start validating in 3 seconds
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kValidateInterval * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self checkServerStatus:ipUrl];
            });
            
        }
        else
        {
            node.failedCount ++;
        }
    }
}

- (void)checkServerStatus:(NSString*)httpUrl
{
    //try connecting server
    NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:httpUrl] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:10];
    NSURLResponse* response;
    NSError* error = nil;
    [NSURLConnection sendSynchronousRequest:req returningResponse:&response error:&error];

    if(error == nil)
    {
        PPDomainRequestResult* result = [PPDomainRequestResult new];
        result.resultUrl = [NSURL URLWithString:httpUrl];
        result.status = PPDomainRequestSuccess;
        [[NSNotificationCenter defaultCenter] postNotificationName:Notif_IPValidateResult object:result];
    }
    else
    {
        dispatch_semaphore_wait(_sema, DISPATCH_TIME_FOREVER);

        PPValidatingNode* node = [self.validatingMap objectForKey:httpUrl];
        if (node) {
            node.failedCount ++;
            if (node.failedCount >= kMaxValidateRetry) {
                PPDomainRequestResult* result = [PPDomainRequestResult new];
                result.resultUrl = [NSURL URLWithString:httpUrl];
                result.status = PPDomainRequestFail;
                [[NSNotificationCenter defaultCenter] postNotificationName:Notif_IPValidateResult object:result];
            }
            else
            {
                //keep trying
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kValidateInterval * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [self checkServerStatus:httpUrl];
                });
                
            }
        }
    
        dispatch_semaphore_signal(_sema);
    }
    
}

@end
