#import <UIKit/UIKit.h>

@protocol SessionsViewControllerDelegate <NSObject>
- (void)sessionsDidChange;
@end

@interface SessionsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate> {
    UITableView *_table;
    id<SessionsViewControllerDelegate> _delegate;
    BOOL _sidebarMode;
    NSInteger _renamingIndex;
    id _renamePopover;
}

@property (nonatomic, assign) id<SessionsViewControllerDelegate> delegate;

- (id)initWithSidebarMode:(BOOL)sidebarMode;
- (void)reload;

@end
