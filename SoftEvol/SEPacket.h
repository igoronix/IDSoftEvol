//
//  SEPacket.h
//  SoftEvol
//
//  Created by Igor on 19.11.14.
//  Copyright (c) 2014 ID. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SEDirector.h"

@interface SEPacket : NSObject <NSCoding>

@property (nonatomic, copy) NSDate *date;
@property (nonatomic, copy) NSNumber *value;
@property (nonatomic, copy) NSString *message;
@property (nonatomic) SEPacketFormat format;
@property (nonatomic) NSUInteger tag;

- (instancetype)initWith:(NSString *)message withValue:(BOOL)value date:(NSDate *)date;
- (instancetype)initWithDic:(NSDictionary *)dic;

- (NSDictionary *)dictionaryWithProperties;

@end
