//
//  SEDirector.m
//  SoftEvol
//
//  Created by Igor on 17.11.14.
//  Copyright (c) 2014 ID. All rights reserved.
//

#import "SEDirector.h"
#import "SEPacket.h"
#import "SEDataManager.h"
#import "SEMoPacket.h"

#import "SRWebSocket.h"
#import "Reachability.h"

NSString *const kSEChangedSocketStatusNotification = @"SEChangedSocketStatusNotification";
NSString *const kSESocketSentMessageNotification = @"SESocketSentMessageNotification";
NSString *const kSESocketReceivedMessageNotification = @"SESocketReceivedMessageNotification";

NSString *const kSEAddOperationToQueueNotification = @"SEAddOperationToQueueNotification";

NSString *const kSESocketStatusKey = @"SESocketStatusKey";
NSString *const kSESocketMessageKey = @"SESocketMessageKey";
NSString *const kSESocketPacketKey = @"SESocketPacketKey";

static NSString *const kSESocketStatePath = @"socket.readyState";


@interface SEDirector()<SRWebSocketDelegate>

@property (nonatomic, retain) SRWebSocket *socket;
@property (nonatomic, retain) NSMutableArray *nonReceivedPackets;
@property (nonatomic, retain) NSMutableArray *pings;

@property (nonatomic) BOOL reachable;
@property (nonatomic, retain) Reachability *internetReachability;
@property (nonatomic, retain) NSTimer *pingTimer;

@end


@implementation SEDirector

#pragma mark - Livecycle

+ (instancetype)sharedInstance
{
    static dispatch_once_t pred;
    static id sharedInstance = nil;
    dispatch_once(&pred, ^{
        sharedInstance = [[self class] new];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _dateFormatter = [NSDateFormatter new];
        [_dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
        [_dateFormatter setDateStyle:NSDateFormatterShortStyle];
        
        _packetsQueue = [NSOperationQueue new];
        _packetsQueue.maxConcurrentOperationCount = 10;
        
        _nonReceivedPackets = [NSMutableArray new];
        _pings = [NSMutableArray new];
        
        _socket = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"ws://echo.websocket.org:80"]]];
        _socket.delegate = self;
        
        [self addObserver:self forKeyPath:kSESocketStatePath options:NSKeyValueObservingOptionNew context:NULL];
        self.socketStatus = 3;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
        
        _internetReachability = [Reachability reachabilityWithHostName:@"echo.websocket.org"];
        [_internetReachability startNotifier];
        [self updateInterface];
        
        _pingTimer = [NSTimer scheduledTimerWithTimeInterval:4 target:self selector:@selector(ping) userInfo:nil repeats:YES];
    }
    return self;
}

- (void)dealloc
{
    [_pingTimer invalidate];
    [_pings release];
    
    [self removeObserver:self forKeyPath:kSESocketStatePath];
    
    [_internetReachability release];
    [_nonReceivedPackets release];
    [_packetsQueue release];
    [_dateFormatter release];
    [_socket release];
    
    [super dealloc];
}

#pragma mark - Accessors

- (void)setSocketStatus:(NSUInteger)socketStatus
{
    if (socketStatus != _socketStatus)
    {
        _socketStatus = socketStatus;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSEChangedSocketStatusNotification object:self userInfo:@{kSESocketStatusKey:[NSNumber numberWithInteger:_socketStatus]}];
    }
}

- (void)setReachable:(BOOL)reachable
{
    if (_reachable != reachable)
    {
        _reachable = reachable;
        
        if (_reachable && self.socket.readyState != 1)
        {
            [self reopen];
        }
        if (_reachable && self.socket.readyState  == 1)
        {
            self.socketStatus = 1;
            self.packetsQueue.suspended = NO;
        }
        else if (!_reachable)
        {
            self.packetsQueue.suspended = YES;
        }
    }
}

#pragma mark - Messaging

- (void)ping
{
    if (self.socket.readyState == 1)
    {
        if ([self.pings count] > 8)
        {
            [self.pings removeAllObjects];
            self.reachable = NO;
            
            self.socketStatus = 0;
        }
        
        NSString *packet = @"pinPacket";
        NSString *str = [NSString stringWithFormat:@"%p", packet];
        [self.pings addObject:str];
        [self.socket sendPing:[str dataUsingEncoding:NSUTF8StringEncoding]];
        [packet release];
    }
}

- (void)addMessage:(NSString *)message withValue:(BOOL)value date:(NSDate *)date inFormat:(SEPacketFormat)format;
{
    SEPacket *packet = [[[SEPacket alloc] initWith:message withValue:value date:date] autorelease];
    
    SEMoPacket *moPacket = [[SEDataManager sharedManager] insertObject:[SEMoPacket class]];
    [moPacket fillWithPacket:packet];
    [[SEDataManager sharedManager] saveContext];
    
    packet.format = format;
    id archiveData = [self messageFromPacket:packet inFormat:format];
    
    [self.nonReceivedPackets addObject:packet];
    [self runOperationWithData:archiveData packet:packet];
}

- (void)reopen
{
    self.socketStatus = 0;
    
    [self removeObserver:self forKeyPath:kSESocketStatePath];
    if (self.socket.retainCount > 1)
    {
        [self.socket release];
        self.socket = nil;
    }
    
    _socket = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"ws://echo.websocket.org:80"]]];
    _socket.delegate = self;
    
    [self addObserver:self forKeyPath:kSESocketStatePath options:NSKeyValueObservingOptionNew context:NULL];
    [_socket open];
}

+ (SEPacket *)findPacketLike:(SEPacket *)newPack inArray:(NSArray *)array
{
    __block NSInteger index = -1;
    NSArray *dates = [array valueForKey:@"date"];
    [dates enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([newPack.date isEqualToDate:obj])
        {
            index = idx;
            *stop = YES;
        }
    }];
    
    return (index >= 0)?array[index]:nil;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:kSESocketStatePath])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
           self.socketStatus = self.socket.readyState; 
        });
    }
}

#pragma mark - <SRWebSocketDelegate>

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
    SEPacket *packet = [self packetFromMessage:message];
    [[NSNotificationCenter defaultCenter] postNotificationName:kSESocketReceivedMessageNotification object:self userInfo:
     @{kSESocketMessageKey:message, kSESocketPacketKey:packet}];
    
    SEPacket *old = [SEDirector findPacketLike:packet inArray:self.nonReceivedPackets];
    if (old)
    {
        [self.nonReceivedPackets removeObject:old];
    }
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
    self.packetsQueue.suspended = NO;
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if ([self.nonReceivedPackets count] > 0)
        {
            for (SEPacket *packet in self.nonReceivedPackets)
            {
                [self runOperationWithData:nil packet:packet];
            }
        }
    });
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    if (error.code == 57)
    {
        self.reachable = NO;
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload
{
    self.reachable = YES;
    NSString *str = [[NSString alloc] initWithData:pongPayload encoding:NSUTF8StringEncoding];
    
    NSInteger i = -1;
    i = [self.pings indexOfObject:str];
    if (i >= 0 && i < [self.pings count])
    {
        [self.pings removeObjectAtIndex:i];
    }
    [str release];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    self.reachable = NO;
}

#pragma mark - Reach

- (void)reachabilityChanged:(NSNotification *)notification
{
    Reachability* curReach = [notification object];
    NSParameterAssert([curReach isKindOfClass:[Reachability class]]);
    [self updateInterface];
}

- (void)updateInterface
{
    NetworkStatus netStatus = [self.internetReachability currentReachabilityStatus];
    self.reachable = netStatus != 0;
}

#pragma mark - Private

- (void)runOperationWithData:(id)archiveData packet:(SEPacket *)packet
{
    BOOL needSendAddNotification = YES;
    if (archiveData == nil && packet != nil)
    {
        archiveData = [self messageFromPacket:packet inFormat:packet.format];
        needSendAddNotification = NO;
    }
    
    NSBlockOperation *operation = [NSBlockOperation new];
    [operation addExecutionBlock:^(void)
     {
         if ([operation isCancelled]) { NSLog(@"Canceled ========= \n\n\n"); return;}
         
         [self.socket send:archiveData];
         
         [[NSNotificationCenter defaultCenter] postNotificationName:kSESocketSentMessageNotification object:self userInfo:
          @{kSESocketMessageKey:archiveData, kSESocketPacketKey:packet}];
         
         if ([operation isCancelled]) { NSLog(@"Canceled ========= \n\n\n"); return; }
     }];
    
    if (needSendAddNotification)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:kSEAddOperationToQueueNotification object:self userInfo:
         @{kSESocketMessageKey:archiveData, kSESocketPacketKey:packet}];
    }
    [self.packetsQueue addOperation:operation];
    [operation release];
}

- (SEPacket *)packetFromMessage:(id)message
{
    NSError *error = nil;
    NSData *data;
    @try {
        data = [message dataUsingEncoding:NSUTF8StringEncoding];
    }
    @catch (NSException *exception)
    {
        data = nil;
    }
    
    if (error == nil && data != nil)
    {
        id object = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        SEPacket *packet = [[[SEPacket alloc] initWithDic:object] autorelease];
        
        return packet;
    }
    else
    {
        error = nil;
        
        NSData *data = [message mutableCopy];
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
        
        SEPacket *packet = nil;
        @try {
            packet = [unarchiver decodeObjectForKey:@"123"];
            [unarchiver finishDecoding];
        }
        @catch (NSException *exception)
        {
            if ([[exception name] isEqualToString:NSInvalidArchiveOperationException]) {
            }
            else
            {
                [exception raise];
            }
        }
        [data release];
        [unarchiver release];
        return packet;
    }
}

- (id)messageFromPacket:(SEPacket *)packet inFormat:(SEPacketFormat)format
{
    id archiveData;
    if (format == SEPacketFormat_XML || format == SEPacketFormat_Binary)
    {
        archiveData = [NSMutableData data];
        NSKeyedArchiver *archiver = [[[NSKeyedArchiver alloc] initForWritingWithMutableData:archiveData] autorelease];
        
        if (format == 1)
        {
            archiver.outputFormat = NSPropertyListXMLFormat_v1_0;
        }
        else
        {
            archiver.outputFormat = kCFPropertyListBinaryFormat_v1_0;
        }
        
        [archiver encodeObject:packet forKey:@"123"];
        [archiver finishEncoding];
    }
    else
    {
        NSError *writeError = nil;
        
        NSDictionary *dic = [packet dictionaryWithProperties];
        if ([NSJSONSerialization isValidJSONObject:dic])
        {
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&writeError];
            archiveData = [[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] autorelease];
        }
    }
    return archiveData;
}

- (NSString *)stringFromPacket:(SEPacket *)packet
{
    NSString *str;
    if (packet != nil)
    {
        str = [NSString stringWithFormat:@"%@ [%@]  \tvalue:%@ \"%@\"",[self.dateFormatter stringFromDate:packet.date], packetFormatToString(packet.format), [packet.value stringValue], packet.message];
    }
    return str;
}

@end
