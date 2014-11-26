//
//  AppDelegate.m
//  SoftEvol
//
//  Created by Igor on 17.11.14.
//  Copyright (c) 2014 ID. All rights reserved.
//

#import "AppDelegate.h"
#import "SEDataManager.h"

@implementation AppDelegate

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    // Saves changes in the application's managed object context before the application terminates.
    [[SEDataManager sharedManager] saveContext];
}

@end
