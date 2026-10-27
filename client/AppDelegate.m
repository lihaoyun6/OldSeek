#import "AppDelegate.h"
#import "ChatViewController.h"
#import "SplitViewController.h"
#import "SessionStore.h"

@interface UIWindow (OldSeekRootViewController)
- (void)setRootViewController:(UIViewController *)controller;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(UIApplication *)application {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    if (![defs boolForKey:@"model_migrated"]) {
        NSString *model = [defs stringForKey:@"model"];
        if (model == nil || [model isEqualToString:@"deepseek-chat"]) {
            [defs setObject:@"deepseek-flash" forKey:@"model"];
        }
        [defs setBool:YES forKey:@"model_migrated"];
        [defs synchronize];
    }

    _window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    BOOL isPad = [[[UIDevice currentDevice] model] rangeOfString:@"iPad"].location != NSNotFound;
    UIViewController *root = nil;
    if (isPad) {
        root = [[SplitViewController alloc] init];
    } else {
        ChatViewController *chat = [[ChatViewController alloc] init];
        _nav = [[UINavigationController alloc] initWithRootViewController:chat];
        [chat release];
        _nav.navigationBar.barStyle = UIBarStyleDefault;
        root = _nav;
    }

    if ([_window respondsToSelector:@selector(setRootViewController:)]) {
        [_window setRootViewController:root];
    } else {
        [_window addSubview:root.view];
    }
    if (isPad) {
        [root release];
    }
    [_window makeKeyAndVisible];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [[SessionStore shared] save];
}

- (void)dealloc {
    [_nav release];
    [_window release];
    [super dealloc];
}

@end
