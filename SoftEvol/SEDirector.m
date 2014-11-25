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
        
        _socket = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"ws://echo.websocket.org:80"]]];
        _socket.delegate = self;
        
        [self addObserver:self forKeyPath:kSESocketStatePath options:NSKeyValueObservingOptionNew context:NULL];
    }
    return self;
}

- (void)dealloc
{
    [self removeObserver:self forKeyPath:kSESocketStatePath];
    
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

#pragma mark - Messaging

- (void)addMessage:(NSString *)message withValue:(BOOL)value date:(NSDate *)date inFormat:(SEPacketFormat)format;
{
    __block SEPacket *packet = [[SEPacket alloc] initWith:message withValue:value date:date];
    
    SEMoPacket *moPacket = [[SEDataManager sharedManager] insertObject:[SEMoPacket class]];
    [moPacket fillWithPacket:packet];
    [[SEDataManager sharedManager] saveContext];
    
    packet.format = format;
    __block id archiveData = [self messageFromPacket:packet inFormat:format];
    
    [self.nonReceivedPackets addObject:packet];
    [self runOperationWithData:archiveData packet:packet];
}

- (void)reopen
{
    [self removeObserver:self forKeyPath:kSESocketStatePath];
    self.socket = nil;
    
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
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    self.packetsQueue.suspended = YES;
}

- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload
{
    NSLog(@"Websocket received pong");
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
        SEPacket *packet = [[SEPacket alloc] initWithDic:object];
        
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
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:archiveData];
        
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
            archiveData = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
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
