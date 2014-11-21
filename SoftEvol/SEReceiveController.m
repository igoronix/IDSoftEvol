//
//  SEReceiveController.m
//  SoftEvol
//
//  Created by Igor on 17.11.14.
//  Copyright (c) 2014 ID. All rights reserved.
//

#import "SEReceiveController.h"
#import "SEDirector.h"
#import "SEPacket.h"
#import "UITextView+Scroll.h"

@interface SEReceiveController ()

@end

@implementation SEReceiveController

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self != nil)
    {
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(socketReceiveMessageNotification:) name:kSESocketReceivedMessageNotification object:[SEDirector sharedInstance]];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.tvLog setTextContainerInset:UIEdgeInsetsMake(16, 16, 0, 0)];
    self.tvLog.text = nil;
    
    self.view.layer.borderWidth = 2.0;
    self.view.layer.borderColor = [UIColor darkGrayColor].CGColor;
    self.view.layer.cornerRadius = 8.0;
}

- (void)socketReceiveMessageNotification:(NSNotification *)notification
{
    if (notification.userInfo != nil)
    {
        SEPacket *newPacket = [notification.userInfo valueForKey:kSESocketPacketKey];
        [self.tvLog insertText:[NSString stringWithFormat:@"[%@] - %@ [%@]\tvalue:%@ \"%@\"\n",
                                [[SEDirector sharedInstance].dateFormatter stringFromDate:[NSDate date]],[[SEDirector sharedInstance].dateFormatter stringFromDate:newPacket.date], packetFormatToString(newPacket.format), [newPacket.value stringValue], newPacket.message]];
        [self.tvLog scrollToBottom];
    }
}

@end
