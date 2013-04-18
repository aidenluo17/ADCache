//
//  ADCacheManager.h
//  
//
//  Created by aidenluo on 4/18/13.
//  Copyright (c) 2013 aidenluo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ADCacheManager : NSObject

@property(nonatomic,copy,readonly)NSString* name;

+ (ADCacheManager*)sharedInstance;
- (id)initWithName:(NSString*)name;

//Accessing Memory and Disk Cache
- (id)objectForKey:(NSString *)key;
- (void)objectForKey:(NSString *)key usingBlock:(void (^)(id object))block;
- (BOOL)objectExistsForKey:(NSString *)key;

- (void)setObject:(id)object forKey:(NSString *)key;
- (void)removeObjectForKey:(id)key;
- (void)removeAllObjects;

//Accessing Only Memory Cache
- (id)objectForKeyInMemory:(NSString *)key;
- (void)objectForKeyInMemory:(NSString *)key usingBlock:(void (^)(id object))block;
- (BOOL)objectExistsForKeyInMemory:(NSString *)key;

- (void)setObjectInMemory:(id)object forKey:(NSString *)key;
- (void)removeObjectForKeyInMemory:(id)key;
- (void)removeAllObjectsInMemory;

//Accessing Only Disk Cache
- (id)objectForKeyOnDisk:(NSString *)key;
- (void)objectForKeyOnDisk:(NSString *)key usingBlock:(void (^)(id object))block;
- (BOOL)objectExistsForKeyOnDisk:(NSString *)key;

- (void)setObjectOnDisk:(id)object forKey:(NSString *)key;
- (void)removeObjectForKeyOnDisk:(id)key;
- (void)removeAllObjectsOnDisk;

@end
