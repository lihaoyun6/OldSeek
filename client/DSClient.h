#import <Foundation/Foundation.h>

@protocol DSClientDelegate <NSObject>
- (void)dsClientDidReceiveDelta:(NSString *)delta;
- (void)dsClientDidFinish;
- (void)dsClientDidFail:(NSString *)message;
@end

@interface DSClient : NSObject {
@private
    id<DSClientDelegate> _delegate;
    NSLock *_lock;
    int _sock;
    volatile BOOL _cancelled;
}

@property (nonatomic, assign) id<DSClientDelegate> delegate;

- (void)sendMessages:(NSArray *)messages model:(NSString *)model apiKey:(NSString *)apiKey;
- (void)cancel;

@end
