//
//  SEDataManager.h
//  SoftEvol
//
//  Created by Igor on 19.11.14.
//  Copyright (c) 2014 ID. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface SEDataManager : NSObject

+ (SEDataManager *)sharedManager;

- (void)saveMessage:(NSString *)massage withValue:(BOOL)value date:(NSDate *)date;

- (id)insertObject:(Class)class;
- (id)allEntityForClass:(Class)class;
- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;

@end
