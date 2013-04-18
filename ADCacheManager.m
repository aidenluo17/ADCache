//
//  ADCacheManager.m
//  
//
//  Created by aidenluo on 4/18/13.
//  Copyright (c) 2013 aidenluo. All rights reserved.
//

#import "ADCacheManager.h"

@interface ADCacheManager ()
{
    NSCache* _cache;
    dispatch_queue_t _queue;
    NSFileManager* _fileManager;
    NSString* _cacheDirectory;
}
- (NSString *)_pathForKey:(NSString *)key;
@end

@implementation ADCacheManager
@synthesize name = _name;

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
  [_cache removeAllObjects];
	[_cache release];
	_cache = nil;
	
	dispatch_release(_queue);
	_queue = nil;
	
	[_name release];
	_name = nil;
	
	[_fileManager release];
	_fileManager = nil;
	
	[_cacheDirectory release];
	_cacheDirectory = nil;
	
	[super dealloc];
}

+ (ADCacheManager*)sharedInstance
{
    static ADCacheManager* instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ADCacheManager alloc] initWithName:@"com.adcache.shared"];
    });
    return instance;
}
- (id)initWithName:(NSString*)name
{
    if ((self = [super init])) {
		_name = [name copy];
		
		_cache = [[NSCache alloc] init];
		_cache.name = name;
		
		_queue = dispatch_queue_create([name cStringUsingEncoding:NSUTF8StringEncoding], DISPATCH_QUEUE_SERIAL);
		
		_fileManager = [[NSFileManager alloc] init];
		NSString *cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
		_cacheDirectory = [[cachesDirectory stringByAppendingFormat:@"/com.adcache/%@", name] retain];
		
		if (![_fileManager fileExistsAtPath:_cacheDirectory]) {
			[_fileManager createDirectoryAtPath:_cacheDirectory withIntermediateDirectories:YES attributes:nil error:nil];
		}
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
	}
	return self;
}

- (void)didReceiveMemoryWarning
{
    [self removeAllObjectsInMemory];
}

#pragma mark - Accessing the Memory Cache and Disk Cache
- (id)objectForKey:(NSString *)key
{
    __block id object = [_cache objectForKey:key];
	if (object)
    {
		return object;
	}
	
	// Get path if object exists
	NSString *path = [self pathForKey:key];
	if (!path)
    {
		return nil;
	}
	
	// Load object from disk
	object = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
	
	// Store in cache
	[_cache setObject:object forKey:key];
	
	return object;
}

- (void)objectForKey:(NSString *)key usingBlock:(void (^)(id object))block
{
    dispatch_async(_queue, ^{
        id object = [[_cache objectForKey:key] retain];
		if (!object)
        {
			object = [[NSKeyedUnarchiver unarchiveObjectWithFile:[self _pathForKey:key]] retain];
			[_cache setObject:object forKey:key];
		}
		
		block([object autorelease]);
    });
}

- (BOOL)objectExistsForKey:(NSString *)key
{
    __block BOOL exists = ([_cache objectForKey:key] != nil);
	if (exists)
    {
		return YES;
	}
	
	dispatch_sync(_queue, ^{
		exists = [_fileManager fileExistsAtPath:[self _pathForKey:key]];
	});
	return exists;
}

- (void)setObject:(id)object forKey:(NSString *)key
{
    if (!object)
    {
		return;
	}
	
	dispatch_async(_queue, ^{
		NSString *path = [self _pathForKey:key];
		
		// Stop if in memory cache or disk cache
		if (([_cache objectForKey:key] != nil) || [_fileManager fileExistsAtPath:path])
        {
			return;
		}
		
		// Save to memory cache
		[_cache setObject:object forKey:key];
		
		// Save to disk cache
		[NSKeyedArchiver archiveRootObject:object toFile:[self _pathForKey:key]];
	});
}

- (void)removeObjectForKey:(id)key
{
    [_cache removeObjectForKey:key];
	
	dispatch_async(_queue, ^{
		[_fileManager removeItemAtPath:[self _pathForKey:key] error:nil];
	});
}

- (void)removeAllObjects
{
    [_cache removeAllObjects];
	
	dispatch_async(_queue, ^{
		for (NSString *path in [_fileManager contentsOfDirectoryAtPath:_cacheDirectory error:nil])
        {
			[_fileManager removeItemAtPath:[_cacheDirectory stringByAppendingPathComponent:path] error:nil];
		}
	});

}

#pragma mark - Accessing the Memory Cache

- (id)objectForKeyInMemory:(NSString *)key
{
    return [_cache objectForKey:key];
}

- (BOOL)objectExistsForKeyInMemory:(NSString *)key
{
    BOOL exists = ([_cache objectForKey:key] != nil);
    return exists;
}

- (void)setObjectInMemory:(id)object forKey:(NSString *)key
{
    if (object == nil) {
        return;
    }
    dispatch_async(_queue, ^{
		// Stop if in memory cache or disk cache
		if (([_cache objectForKey:key] != nil))
        {
			return;
		}
		// Save to memory cache
		[_cache setObject:object forKey:key];
	});
}

- (void)removeObjectForKeyInMemory:(id)key
{
    [_cache removeObjectForKey:key];
}

- (void)removeAllObjectsInMemory
{
    [_cache removeAllObjects];
}

#pragma mark - Accessing the Disk Cache

- (id)objectForKeyOnDisk:(NSString *)key
{
    id object = nil;
    NSString *path = [self pathForKey:key];
	if (!path)
    {
		return nil;
	}
	
	// Load object from disk
	object = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
	
	return object;
}

- (void)objectForKeyOnDisk:(NSString *)key usingBlock:(void (^)(id object))block
{
    dispatch_async(_queue, ^{
        id object = [[NSKeyedUnarchiver unarchiveObjectWithFile:[self _pathForKey:key]] retain];
		block([object autorelease]);
	});
}

- (BOOL)objectExistsForKeyOnDisk:(NSString *)key
{
    __block BOOL exists = NO;
	dispatch_sync(_queue, ^{
		exists = [_fileManager fileExistsAtPath:[self _pathForKey:key]];
	});
	return exists;
}

- (void)setObjectOnDisk:(id)object forKey:(NSString *)key
{
    if (!object) {
		return;
	}
	
	dispatch_async(_queue, ^{
		NSString *path = [self _pathForKey:key];
		
		// Stop if in memory cache or disk cache
		if ([_fileManager fileExistsAtPath:path]) {
			return;
		}
    
		// Save to disk cache
		[NSKeyedArchiver archiveRootObject:object toFile:[self _pathForKey:key]];
	});
}

- (void)removeObjectForKeyOnDisk:(id)key
{
    dispatch_async(_queue, ^{
		[_fileManager removeItemAtPath:[self _pathForKey:key] error:nil];
	});
}

- (void)removeAllObjectsOnDisk
{
    dispatch_async(_queue, ^{
		for (NSString *path in [_fileManager contentsOfDirectoryAtPath:_cacheDirectory error:nil]) {
			[_fileManager removeItemAtPath:[_cacheDirectory stringByAppendingPathComponent:path] error:nil];
		}
	});
}

- (NSString *)pathForKey:(NSString *)key
{
	if ([self objectExistsForKey:key])
    {
		return [self _pathForKey:key];
	}
	return nil;
}


#pragma mark - Private

- (NSString *)_pathForKey:(NSString *)key
{
	return [_cacheDirectory stringByAppendingPathComponent:key];
}

@end
