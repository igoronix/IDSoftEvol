//
//  SESentController.m
//  SoftEvol
//
//  Created by Igor on 17.11.14.
//  Copyright (c) 2014 ID. All rights reserved.
//

#import "SESentController.h"
#import "SEDirector.h"
#import "SEPacket.h"

@interface SESentController ()

@property (nonatomic, retain) NSMutableArray *operations;

@end

@implementation SESentController

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self != nil)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addOperationToQueueNotification:) name:kSEAddOperationToQueueNotification object:[SEDirector sharedInstance]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(socketSentMessageNotification:) name:kSESocketSentMessageNotification object:[SEDirector sharedInstance]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(socketReceiveMessageNotification:) name:kSESocketReceivedMessageNotification object:[SEDirector sharedInstance]];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.layer.borderWidth = 2.0;
    self.view.layer.borderColor = [UIColor darkGrayColor].CGColor;
    self.view.layer.cornerRadius = 8.0;
    
    self.operations = [NSMutableArray array];
    [self.tableView reloadData];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super dealloc];
}

#pragma mark - Notifications

- (void)addOperationToQueueNotification:(NSNotification *)notification
{
    if (notification.userInfo != nil)
    {
        SEPacket *packet = [notification.userInfo valueForKey:kSESocketPacketKey];
        [self.operations addObject:packet];
        NSIndexPath* ipath = [NSIndexPath indexPathForRow: [self.operations indexOfObject:packet] inSection:0];
        
        [self.tableView reloadData];
        [self.tableView scrollToRowAtIndexPath:ipath atScrollPosition: UITableViewScrollPositionTop animated:YES];
    }
}

- (void)socketSentMessageNotification:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^(void)
    {
        if (notification.userInfo != nil)
        {
            SEPacket *packet = [notification.userInfo valueForKey:kSESocketPacketKey];
            packet.tag = 1;
            NSUInteger i = [self.operations indexOfObject:packet];
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:i inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
        }
    });
}

- (void)socketReceiveMessageNotification:(NSNotification *)notification
{
    if (notification.userInfo != nil)
    {
        SEPacket *newPacket = [notification.userInfo valueForKey:kSESocketPacketKey];
        SEPacket *oldPacket = [self findPacketLike:newPacket];
        
        NSUInteger i = [self.operations indexOfObject:oldPacket];
        if (oldPacket != nil)
        {
            oldPacket.tag = 2;
        }
        
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:i inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (SEPacket *)findPacketLike:(SEPacket *)newPack
{
    return [SEDirector findPacketLike:newPack inArray:self.operations];
}

#pragma mark - TBV

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.operations count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    SEPacket *packet = self.operations[indexPath.row];
    cell.textLabel.text = [[SEDirector sharedInstance] stringFromPacket:packet];
    
    UIColor *color;
    switch (packet.tag)
    {
        case 0:
            color = [UIColor lightGrayColor];
            break;
            
        case 1:
            color = [UIColor redColor];
            break;
            
        case 2:
            color = [UIColor greenColor];
            break;
            
        default:
            break;
    }
    cell.backgroundColor = color;
    
    return cell;
}

@end
