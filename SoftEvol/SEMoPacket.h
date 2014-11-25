//
//  SEMoPacket.h
//  SoftEvol
//
//  Created by Igor on 19.11.14.
//  Copyright (c) 2014 ID. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class SEPacket;

@interface SEMoPacket : NSManagedObject

@property (nonatomic, retain) NSDate * date;
@property (nonatomic, retain) NSNumber * value;
@property (nonatomic, retain) NSString * message;

- (void)fillWithPacket:(SEPacket *)packet;

@end
