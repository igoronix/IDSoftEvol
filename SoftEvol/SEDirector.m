//
//  SEDirector.m
//  SoftEvol
//
//  Created by Igor on 17.11.14.
//  Copyright (c) 2014 ID. All rights reserved.
//

#import "SEDirector.h"
#import "SEPacket.h"
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

@property(nonatomic, retain) SRWebSocket *socket;

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
        _socket = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"ws://echo.websocket.org:80"]]];
        _socket.delegate = self;
        
        [self addObserver:self forKeyPath:kSESocketStatePath options:NSKeyValueObservingOptionNew context:NULL];
        [_socket open];
    }
    return self;
}

- (void)dealloc
{
    [self removeObserver:self forKeyPath:kSESocketStatePath];
    
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
//    for (NSUInteger i = 0; i < 20; i++)
//    {
//        date = [NSDate dateWithTimeInterval:i sinceDate:date];
//        __block SEPacket *packet = [[SEPacket alloc] initWith:[NSString stringWithFormat:@"%i", i] withValue:value date:date];//message withValue:value date:date];
    __block SEPacket *packet = [[SEPacket alloc] initWith:message withValue:value date:date];
    packet.format = format;
        __block id archiveData = [self messageFromPacket:packet inFormat:format];
        
        NSBlockOperation *operation = [NSBlockOperation new];
        [operation addExecutionBlock:^(void)
         {
             if ([operation isCancelled]) { NSLog(@"Canceled ========= \n\n\n"); return;}
             
             [self.socket send:archiveData];
             
             [[NSNotificationCenter defaultCenter] postNotificationName:kSESocketSentMessageNotification object:self userInfo:
              @{kSESocketMessageKey:archiveData, kSESocketPacketKey:packet}];
             
             if ([operation isCancelled]) { NSLog(@"Canceled ========= \n\n\n"); return; }
         }];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSEAddOperationToQueueNotification object:self userInfo:
         @{kSESocketMessageKey:archiveData, kSESocketPacketKey:packet}];
        [self.packetsQueue addOperation:operation];
//    }
}

- (id)messageFromPacket:(SEPacket *)packet inFormat:(SEPacketFormat)format
{
    id archiveData;
    if (format == 1 || format == 3)
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

- (NSString *)stringFromPacket:(SEPacket *)packet
{
    NSString *str;
    if (packet != nil)
    {
        str = [NSString stringWithFormat:@"%@ [%@]  \tvalue:%@ \"%@\"",[self.dateFormatter stringFromDate:packet.date], packetFormatToString(packet.format), [packet.value stringValue], packet.message];
    }
    return str;
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
    [[NSNotificationCenter defaultCenter] postNotificationName:kSESocketReceivedMessageNotification object:self userInfo:
     @{kSESocketMessageKey:message, kSESocketPacketKey:[self packetFromMessage:message]}];
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
    NSLog(@"Websocket Connected");
    self.packetsQueue.suspended = NO;
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    NSLog(@":( Websocket Failed With Error %@", error);
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    NSLog(@"WebSocket closed");
    self.packetsQueue.suspended = YES;
}

- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload
{
    NSLog(@"Websocket received pong");
}

@end
