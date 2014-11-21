//
//  UITextView+Scroll.m
//  SoftEvol
//
//  Created by Igor on 21.11.14.
//  Copyright (c) 2014 ID. All rights reserved.
//

#import "UITextView+Scroll.h"

@implementation UITextView (Scroll)

- (void)scrollToBottom
{
    NSRange range = NSMakeRange(self.text.length - 1, 1);
    [self scrollRangeToVisible:range];
}

@end