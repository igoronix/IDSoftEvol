//
//  SEDirector.h
//  SoftEvol
//
//  Created by Igor on 17.11.14.
//  Copyright (c) 2014 ID. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SEPacket;

extern NSString *const kSEChangedSocketStatusNotification;
extern NSString *const kSESocketSentMessageNotification;
extern NSString *const kSESocketReceivedMessageNotification;

extern NSString *const kSEAddOperationToQueueNotification;

extern NSString *const kSESocketStatusKey;
extern NSString *const kSESocketMessageKey;
extern NSString *const kSESocketPacketKey;

typedef NS_ENUM (NSUInteger, SEPacketFormat)
{
    SEPacketFormat_None = 0,
    SEPacketFormat_XML,
    SEPacketFormat_JSON,
    SEPacketFormat_Binary
};

#define socketStatusString(enum) [@[@"CONNECTING",@"OPEN",@"CLOSING", @"CLOSED"] objectAtIndex:enum]
#define packetFormatToString(enum) [@[@"None",@"XML",@"JSON", @"Binary"] objectAtIndex:enum]

@interface SEDirector : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, readonly) NSUInteger socketStatus;
@property (nonatomic, retain) NSOperationQueue *packetsQueue;
@property (nonatomic, retain) NSDateFormatter *dateFormatter;

- (void)addMessage:(NSString *)message withValue:(BOOL)value date:(NSDate *)date inFormat:(SEPacketFormat)format;

- (NSString *)stringFromPacket:(SEPacket *)packet;

- (void)reopen;

@end
