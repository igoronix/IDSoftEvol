//
//  SEMoPacket.m
//  SoftEvol
//
//  Created by Igor on 19.11.14.
//  Copyright (c) 2014 ID. All rights reserved.
//

#import "SEMoPacket.h"
#import "SEPacket.h"

@implementation SEMoPacket

@dynamic date;
@dynamic value;
@dynamic message;

- (void)fillWithPacket:(SEPacket *)packet
{
    self.date = packet.date;
    self.message = packet.message;
    self.value = packet.value;
}

@end
