//
//  PPDNSMappingManager.m
//  PPDNSMappingDemo
//
//  Created by gao feng on 16/1/19.
//  Copyright © 2016年 gao feng. All rights reserved.
//

#import "PPDNSMappingManager.h"
#import "PPWeakTimer.h"
#import "Reachability.h"
#import "PPDomainRequestResult.h"
#import "PPResolvedUrl.h"
#import "PPMappingUtil.h"
#import "PPMappingNode.h"
#import <libkern/OSAtomic.h>
#import "PPIPValidator.h"
#import "PPDNSReporter.h"

#define kMappingFileName @"dns_mapping"
#define kPreviousMappingFileName @"dns_mapping_previous"

@interface PPDNSMappingManager ()

//default dns mapping, latest copy
@property (nonatomic, strong) NSDictionary*                     dnsMapping;
//previous dns mapping, previous copy
@property (nonatomic, strong) NSDictionary*                     previousDNSMapping;
//real mapping source, with health checking
@property (nonatomic, strong) NSMutableDictionary*              mappingSource;


//timer to sync mapping file from server
@property (nonatomic, strong) NSTimer*                          syncTimer;

//server url to retrieve mapping data
@property (nonatomic, strong) NSString*                         srcUrl;

@end

@implementation PPDNSMappingManager
{
    dispatch_semaphore_t _sema;
    time_t _lastSyncTime;
}

+ (instancetype)sharedInstance
{
    static PPDNSMappingManager* instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [PPDNSMappingManager new];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        _sema = dispatch_semaphore_create(1);
        _lastSyncTime = 0;
        
        self.dnsMapping = @{};
        self.previousDNSMapping = @{};
        self.mappingSource = @{}.mutableCopy;
        
        //observe events
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(detectDomainRequestResult:) name:Notif_DomainRequestResult object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(detectIPValidatorResult:) name:Notif_IPValidateResult object:nil];
    }
    return self;
}

- (PPResolvedUrl*)resolveUrl:(NSURL*)originalUrl
{
    if (originalUrl == nil || originalUrl.absoluteString.length == 0) {
        NSLog(@"empty original url.");
        return nil;
    }
    
    PPResolvedUrl* resolvedEntry = nil;
    
    //retrieve resolved url from our mapping
    NSString* urlKey = [PPMappingUtil getUrlMappingKey:originalUrl];
    NSString* mappedUrl = [self getMappingEntry:urlKey withFailLimit:0 withMappingDic:self.dnsMapping];
    if (mappedUrl.length == 0) {
        mappedUrl = [self getMappingEntry:urlKey withFailLimit:0 withMappingDic:self.previousDNSMapping];
    }

    resolvedEntry = [PPResolvedUrl new];
    resolvedEntry.resolvedHost = [NSURL URLWithString:urlKey].host;
    if (mappedUrl.length != 0) {
        resolvedEntry.resolvedUrl = [originalUrl.absoluteString stringByReplacingOccurrencesOfString:urlKey withString:mappedUrl];
    }
    else
    {
        resolvedEntry.resolvedUrl = originalUrl.absoluteString;
    }
    
    return resolvedEntry;
}

- (NSString*)getMappingEntry:(NSString*)urlKey withFailLimit:(int)limit withMappingDic:(NSDictionary*)mappingDic
{
    NSString* mappedUrl = nil;
    NSURL* tmpUrl = [NSURL URLWithString:urlKey];
    
    BOOL shouldSkipMapping = false;
    
    //if it's ip address already, no need to do mapping
    if ([PPMappingUtil isIPAddress:tmpUrl.host]) {
        shouldSkipMapping = true;
    }
    
    dispatch_semaphore_wait(_sema, DISPATCH_TIME_FOREVER);
    
    NSArray* mappingUrls = [mappingDic objectForKey:urlKey];
    //no mapping found, skip
    if (mappingUrls.count == 0) {
        shouldSkipMapping = true;
    }
    
    //do mapping
    if (shouldSkipMapping == false) {
        for (NSString* source in mappingUrls) {
            PPMappingNode* node = [_mappingSource objectForKey:source];
            if (node && node.requestFailedCount <= limit) {
                mappedUrl = node.mappedUrl;
                break;
            }
        }
    }
    
    dispatch_semaphore_signal(_sema);
    
    return mappedUrl;
}

#pragma mark- initial config
- (void)setDefaultLocalMapping:(NSString*)filePath
{
    NSData* mappingData = [NSData dataWithContentsOfFile:filePath];
    
    if (mappingData.length == 0) {
        return;
    }
    
    NSDictionary* mappingDic = [NSJSONSerialization JSONObjectWithData:mappingData options:NSJSONReadingMutableContainers error:nil];
    [self parseDNSMapping:mappingDic];
}

- (void)parseDNSMapping:(NSDictionary*)mappingDic
{
    if (mappingDic == nil) {
        NSLog(@"mapping is nil, err");
        return;
    }

    dispatch_semaphore_wait(_sema, DISPATCH_TIME_FOREVER);
    NSDictionary* prevMapping = [NSDictionary dictionaryWithDictionary:self.dnsMapping];
    NSDictionary* newMapping = [NSDictionary dictionaryWithDictionary:mappingDic];
    dispatch_semaphore_signal(_sema);
    
    [self buildMappingData:newMapping withPreviousMapping:prevMapping];
}


#pragma mark- sync mapping logic
- (void)syncMappingWithServer
{
    if ([NSThread isMainThread]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self syncMappingWithServer];
        });
        return;
    }
    NSAssert([NSThread isMainThread] == false, @"run this from worker thread");
    
    //do frequency check, ignore requests within 3 seconds
    time_t now = time(0);
    if (now - _lastSyncTime < 3) {
        return;
    }
    _lastSyncTime = now;
    
    //retrieve mapping data from server
    NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:_srcUrl] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:10];
    NSURLResponse* response;
    NSError* error = nil;
    
    NSData* resultData = [NSURLConnection sendSynchronousRequest:req returningResponse:&response error:&error];
    if(resultData.length == 0)
    {
        NSLog(@"empty response, err");
        return;
    }
    
    NSDictionary* mappingDic = [NSJSONSerialization JSONObjectWithData:resultData options:NSJSONReadingMutableContainers error:nil];
    [self parseDNSMapping:mappingDic];
    
    //save mapping to disk
    [self saveMappingToDisk];
}

- (void)startSyncTimerWithInterval:(NSTimeInterval)interval withSrcUrl:(NSString*)srcUrl
{
    NSAssert([NSThread isMainThread], @"must run in main thread");
    
    if (interval < 3) {
        return;
    }
    
    self.srcUrl = srcUrl;
    __weak __typeof(self) wself = self;
    self.syncTimer = [PPWeakTimer scheduledTimerWithTimeInterval:interval target:wself selector:@selector(syncMappingWithServer) userInfo:nil repeats:true];
    [self.syncTimer fire];
}

#pragma mark- detect mapping events
- (void)detectDomainRequestResult:(NSNotification*)notif
{
    PPDomainRequestResult* result = notif.object;
    if (result.resultUrl == nil) {
        return;
    }
    
    if (result.status == PPDomainRequestSuccess) {
        //happy news
    }
    else if(result.status == PPDomainRequestFail)
    {
        //ignore result from network lost
        NetworkStatus status = [[Reachability reachabilityForInternetConnection] currentReachabilityStatus];
        if (status == NotReachable) {
            return;
        }
        
        NSString* urlKey = [PPMappingUtil getUrlMappingKey:result.resultUrl];
        
        dispatch_semaphore_wait(_sema, DISPATCH_TIME_FOREVER);
        PPMappingNode* node = [self.mappingSource objectForKey:urlKey];
        if (node != nil) {
            //increase fail count
            node.requestFailedCount ++;
        }
        dispatch_semaphore_signal(_sema);
        
        //validate this ip again with validator
        [[PPIPValidator sharedInstance] validateIP:result.resultUrl.absoluteString];
    }
}


- (void)detectIPValidatorResult:(NSNotification*)notif
{
    PPDomainRequestResult* result = notif.object;
    if (result.resultUrl == nil) {
        return;
    }
    NSString* urlKey = [PPMappingUtil getUrlMappingKey:result.resultUrl];
    
    if (result.status == PPDomainRequestSuccess) {
        dispatch_semaphore_wait(_sema, DISPATCH_TIME_FOREVER);
        PPMappingNode* node = [self.mappingSource objectForKey:urlKey];
        if (node != nil) {
            //reset fail count
            node.requestFailedCount = 0;
        }
        dispatch_semaphore_signal(_sema);
    }
    else if(result.status == PPDomainRequestFail)
    {
        dispatch_semaphore_wait(_sema, DISPATCH_TIME_FOREVER);
        PPMappingNode* node = [self.mappingSource objectForKey:urlKey];
        dispatch_semaphore_signal(_sema);
        
        //validator failed too, report to server
        [[PPDNSReporter sharedInstance] reportFailedUrl:result.resultUrl.absoluteString withFailedCount:node.requestFailedCount];
    }
}

#pragma mark- mapping file reading and writting
- (void)saveMappingToDisk
{
    if (self.dnsMapping) {
        NSString* allotdnsmappath = [NSHomeDirectory() stringByAppendingPathComponent:kMappingFileName];
        [NSKeyedArchiver archiveRootObject:self.dnsMapping toFile:allotdnsmappath];
    }
    
    if (self.previousDNSMapping) {
        NSString* lastallotdnsmap = [NSHomeDirectory() stringByAppendingPathComponent:kPreviousMappingFileName];
        [NSKeyedArchiver archiveRootObject:self.previousDNSMapping toFile:lastallotdnsmap];
    }
}

- (void)readMappingFromDisk
{
    NSString* mappingPath = [NSHomeDirectory() stringByAppendingPathComponent:kMappingFileName];
    NSMutableDictionary* mappingDic = [NSKeyedUnarchiver unarchiveObjectWithFile:mappingPath];
    
    NSString* preMappingPath = [NSHomeDirectory() stringByAppendingPathComponent:kPreviousMappingFileName];
    NSMutableDictionary* prevMappingDic = [NSKeyedUnarchiver unarchiveObjectWithFile:preMappingPath];
    
    [self buildMappingData:mappingDic withPreviousMapping:prevMappingDic];
}

#pragma mark- build mapping data
- (void)buildMappingData:(NSDictionary*)mapping withPreviousMapping:(NSDictionary*)preMapping
{
    dispatch_semaphore_wait(_sema, DISPATCH_TIME_FOREVER);
    
    if (mapping) {
        self.dnsMapping = [NSDictionary dictionaryWithDictionary:mapping];
    }
    if (preMapping) {
        self.previousDNSMapping = [NSDictionary dictionaryWithDictionary:preMapping];
    }
    
    //build mapping source
    if (self.dnsMapping == nil || self.dnsMapping.allKeys.count == 0) {
        return;
    }
    
    [self.mappingSource removeAllObjects];
    
    [self buildMappingSourceFromDic:self.previousDNSMapping];
    [self buildMappingSourceFromDic:self.dnsMapping];
    
    dispatch_semaphore_signal(_sema);
}

- (void)buildMappingSourceFromDic:(NSDictionary*)dic
{
    if (dic == nil) {
        return;
    }
    [dic enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSArray* sourceList = obj;
        for (NSString* source in sourceList) {
            
            PPMappingNode* node = [PPMappingNode new];
            node.mappedUrl = source;
            node.requestFailedCount = 0;
            
            [self.mappingSource setObject:node forKey:source];
        }
    }];
}

@end
