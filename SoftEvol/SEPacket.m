//
//  SEPacket.m
//  SoftEvol
//
//  Created by Igor on 19.11.14.
//  Copyright (c) 2014 ID. All rights reserved.
//

#import "SEPacket.h"
#import <objc/runtime.h>

@implementation SEPacket

- (instancetype)initWith:(NSString *)message withValue:(BOOL)value date:(NSDate *)date
{
    self = [super init];
    if (self != nil)
    {
        _message = [message copy];
        _value = [NSNumber numberWithBool:value];
        _date = [date copy];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _date = [[aDecoder decodeObjectForKey:@"seDate"] retain];
        _value = [[aDecoder decodeObjectForKey:@"seValue"] retain];
        _message = [[aDecoder decodeObjectForKey:@"seMessage"] retain];
        _format = [[aDecoder decodeObjectForKey:@"seFormat"] integerValue];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:_date forKey:@"seDate"];
    [encoder encodeObject:_value forKey:@"seValue"];
    [encoder encodeObject:_message forKey:@"seMessage"];
    [encoder encodeObject:[NSNumber numberWithInteger:_format] forKey:@"seFormat"];
}

- (instancetype)initWithDic:(NSDictionary *)dic
{
    self = [super init];
    if (self != nil)
    {
        _message = dic[@"message"];
        _value = dic[@"value"];
        _date = [NSDate dateWithTimeIntervalSinceReferenceDate:[dic[@"date"] doubleValue]];
        _format = SEPacketFormat_JSON;
    }
    return self;
}

- (NSDictionary *)dictionaryWithProperties
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    unsigned count;
    objc_property_t *properties = class_copyPropertyList([self class], &count);
    
    for (int i = 0; i < count; i++) {
        NSString *key = [NSString stringWithUTF8String:property_getName(properties[i])];
        
        id obj = [self valueForKey:key];
        if ([obj isKindOfClass:[NSDate class]])
        {
            NSDate *d = obj;
            
            [dict setObject:[NSNumber numberWithDouble:[d timeIntervalSinceReferenceDate]] forKey:key];
        }
        else if (![NSStringFromClass([obj class])isEqualToString:@"__NSCFNumber"])
        {
            [dict setObject:obj forKey:key];
        }
    }
    
    free(properties);
    
    return [NSDictionary dictionaryWithDictionary:dict];
}

- (void)dealloc
{
    [_message release];
    [_date release];
    [_value release];
    
    [super dealloc];
}

@end
