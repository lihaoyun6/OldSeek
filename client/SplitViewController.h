#import <UIKit/UIKit.h>
#import "SessionsViewController.h"

@class ChatViewController;

@interface SplitViewController : UIViewController <SessionsViewControllerDelegate> {
    UINavigationController *_sessionsNav;
    UINavigationController *_chatNav;
    SessionsViewController *_sessionsViewController;
    ChatViewController *_chatViewController;
    UIView *_divider;
    UIView *_cornerOverlay;
    BOOL _sidebarVisible;
}

@end
