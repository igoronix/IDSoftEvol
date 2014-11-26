//
//  SEInputController.m
//  SoftEvol
//
//  Created by Igor on 17.11.14.
//  Copyright (c) 2014 ID. All rights reserved.
//

#import "SEInputController.h"
#import "SEDirector.h"
#import "UITextView+Scroll.h"

@implementation SEInputController

#pragma mark - Livecycle

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self != nil)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changedSocketStatusNotification:) name:kSEChangedSocketStatusNotification object:[SEDirector sharedInstance]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(socketSentMessageNotification:) name:kSESocketSentMessageNotification object:[SEDirector sharedInstance]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(socketReceivedMessageNotification:) name:kSESocketReceivedMessageNotification object:[SEDirector sharedInstance]];
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
    self.tvLog.layer.borderWidth = 2.0;
    self.tvLog.layer.borderColor = [UIColor darkGrayColor].CGColor;
    self.tvLog.layer.cornerRadius = 8.0;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self updateStatus];
}

#pragma mark - Actions

- (IBAction)addMessage:(id)sender
{
    if ([SEDirector sharedInstance].socketStatus != 1)
    {
        [[SEDirector sharedInstance] reopen];
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [[SEDirector sharedInstance] addMessage:self.tfMessage.text withValue:self.swBool.on date:[NSDate date] inFormat:self.scFormat.selectedSegmentIndex+1];
        });
    }
}

#pragma mark - Notifications

- (void)changedSocketStatusNotification:(NSNotification *)notification
{
    if (notification.userInfo != nil)
    {
        [self updateStatus];
    }
}

- (void)socketSentMessageNotification:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        id message = [notification.userInfo valueForKey:kSESocketMessageKey];
        NSString *logString = [NSString stringWithFormat:@"[%@]  SENT:\n%@\n", [[SEDirector sharedInstance].dateFormatter stringFromDate:[NSDate date]], message];
        [self insert:logString];
    });
}

- (void)socketReceivedMessageNotification:(NSNotification *)notification
{
    id message = [notification.userInfo valueForKey:kSESocketMessageKey];
    NSString *logString = [NSString stringWithFormat:@"[%@]  RECEIVED:\n%@\n", [[SEDirector sharedInstance].dateFormatter stringFromDate:[NSDate date]], message];
    [self insert:logString];
}

- (void)updateStatus
{
    NSUInteger status = [SEDirector sharedInstance].socketStatus;
    
    self.lbStatus.text = socketStatusString(status);
    self.lbStatus.textColor = (status == 1)?[UIColor greenColor]:[UIColor redColor];
    
    NSString *logString = [NSString stringWithFormat:@"[%@]  STATUS: %@\n", [[SEDirector sharedInstance].dateFormatter stringFromDate:[NSDate date]], socketStatusString(status)];
    [self insert:logString];
    
    self.aiIndicator.hidden = (status == 1 || status == 3);
    self.btSend.enabled = status == 1;
}

- (void)insert:(NSString *)str
{
    [self.tvLog insertText:str];
    [self.tvLog scrollToBottom];
}

@end
