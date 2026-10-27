#import "SessionStore.h"

static SessionStore *gSharedStore = nil;

@implementation SessionStore

+ (SessionStore *)shared {
    if (gSharedStore == nil) gSharedStore = [[SessionStore alloc] init];
    return gSharedStore;
}

+ (NSString *)dataDirectory {
    NSFileManager *fm = [NSFileManager defaultManager];

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                         NSUserDomainMask, YES);
    NSString *directory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    if (directory != nil && ![fm fileExistsAtPath:directory]) {
        [fm createDirectoryAtPath:directory attributes:nil];
    }
    if (directory != nil && [fm isWritableFileAtPath:directory]) {
        return directory;
    }

    paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                NSUserDomainMask, YES);
    directory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    if (directory == nil) return nil;
    directory = [directory stringByAppendingPathComponent:@"OldSeek"];
    if (![fm fileExistsAtPath:directory]) {
        [fm createDirectoryAtPath:directory attributes:nil];
    }
    return directory;
}

- (id)init {
    if ((self = [super init])) {
        _sessions = [[NSMutableArray alloc] init];

        NSString *directory = [SessionStore dataDirectory];
        if (directory != nil) {
            _path = [[directory stringByAppendingPathComponent:@"sessions.plist"] retain];
        }

        NSArray *raw = [NSArray arrayWithContentsOfFile:_path];
        NSDictionary *rawSession;
        for (rawSession in raw) {
            NSMutableDictionary *session = [NSMutableDictionary dictionary];
            NSString *title = [rawSession objectForKey:@"title"];
            [session setObject:(title ? title : @"") forKey:@"title"];
            [session setObject:[self mutableMessages:[rawSession objectForKey:@"messages"]]
                        forKey:@"messages"];
            [_sessions addObject:session];
        }

        if ([_sessions count] == 0) {
            [self createSessionWithoutSaving];
        }

        NSInteger index = [[NSUserDefaults standardUserDefaults] integerForKey:@"current_session"];
        if (index < 0 || index >= (NSInteger)[_sessions count]) index = 0;
        _currentIndex = index;
    }
    return self;
}

- (NSMutableArray *)mutableMessages:(NSArray *)raw {
    NSMutableArray *messages = [NSMutableArray array];
    NSDictionary *rawMessage;
    for (rawMessage in raw) {
        NSMutableDictionary *message = [NSMutableDictionary dictionary];
        NSString *role = [rawMessage objectForKey:@"role"];
        NSString *text = [rawMessage objectForKey:@"text"];
        if ([role isEqualToString:@"assistant"] && [text length] == 0) continue;
        [message setObject:(role ? role : @"") forKey:@"role"];
        [message setObject:[[(text ? text : @"") mutableCopy] autorelease] forKey:@"text"];
        NSArray *images = [rawMessage objectForKey:@"images"];
        if ([images isKindOfClass:[NSArray class]] && [images count] > 0) {
            [message setObject:images forKey:@"images"];
        }
        NSArray *thumbs = [rawMessage objectForKey:@"image_thumbs"];
        if ([thumbs isKindOfClass:[NSArray class]] && [thumbs count] > 0) {
            [message setObject:thumbs forKey:@"image_thumbs"];
        }
        [messages addObject:message];
    }
    return messages;
}

- (void)createSessionWithoutSaving {
    NSMutableDictionary *session = [NSMutableDictionary dictionary];
    [session setObject:@"" forKey:@"title"];
    [session setObject:[NSMutableArray array] forKey:@"messages"];
    [_sessions insertObject:session atIndex:0];
    _currentIndex = 0;
}

- (NSArray *)sessions {
    return _sessions;
}

- (NSInteger)currentIndex {
    return _currentIndex;
}

- (NSMutableDictionary *)currentSession {
    if ([_sessions count] == 0) [self createSessionWithoutSaving];
    return [_sessions objectAtIndex:_currentIndex];
}

- (void)selectSessionAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)[_sessions count]) return;
    _currentIndex = index;
    [self save];
}

- (void)renameSessionAtIndex:(NSInteger)index title:(NSString *)title {
    if (index < 0 || index >= (NSInteger)[_sessions count]) return;
    NSMutableDictionary *session = [_sessions objectAtIndex:index];
    [session setObject:(title ? title : @"") forKey:@"title"];
    [self save];
}

- (void)createSession {
    [self createSessionWithoutSaving];
    [self save];
}

- (void)deleteSessionAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)[_sessions count]) return;
    [_sessions removeObjectAtIndex:index];
    if ([_sessions count] == 0) {
        [self createSessionWithoutSaving];
    } else {
        if (index < _currentIndex) _currentIndex--;
        if (_currentIndex >= (NSInteger)[_sessions count]) {
            _currentIndex = (NSInteger)[_sessions count] - 1;
        }
    }
    [self save];
}

- (void)save {
    if (_path != nil) {
        [_sessions writeToFile:_path atomically:YES];
    }
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setInteger:_currentIndex forKey:@"current_session"];
    [defs synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SessionsChanged"
                                                        object:self];
}

- (void)dealloc {
    [_sessions release];
    [_path release];
    [super dealloc];
}

@end
