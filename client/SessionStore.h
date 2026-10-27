#import <Foundation/Foundation.h>

@interface SessionStore : NSObject {
    NSMutableArray *_sessions;
    NSInteger _currentIndex;
    NSString *_path;
}

+ (SessionStore *)shared;
+ (NSString *)dataDirectory;

- (NSArray *)sessions;
- (NSInteger)currentIndex;
- (NSMutableDictionary *)currentSession;

- (void)selectSessionAtIndex:(NSInteger)index;
- (void)renameSessionAtIndex:(NSInteger)index title:(NSString *)title;
- (void)createSession;
- (void)deleteSessionAtIndex:(NSInteger)index;
- (void)save;

@end
