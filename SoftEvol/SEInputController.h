//
//  SEInputController.h
//  SoftEvol
//
//  Created by Igor on 17.11.14.
//  Copyright (c) 2014 ID. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SEInputController : UIViewController

@property (nonatomic, assign) IBOutlet UILabel *lbStatus;
@property (nonatomic, assign) IBOutlet UIActivityIndicatorView *aiIndicator;
@property (nonatomic, assign) IBOutlet UITextView *tvLog;

@property (nonatomic, assign) IBOutlet UITextField *tfMessage;
@property (nonatomic, assign) IBOutlet UISwitch *swBool;
@property (nonatomic, assign) IBOutlet UISegmentedControl *scFormat;
@property (nonatomic, assign) IBOutlet UIButton *btSend;

- (IBAction)addMessage:(id)sender;

@end
