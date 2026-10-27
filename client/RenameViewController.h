#import <UIKit/UIKit.h>

@class RenameViewController;

@protocol RenameViewControllerDelegate <NSObject>
- (void)renameViewController:(RenameViewController *)controller
          didFinishWithTitle:(NSString *)title;
- (void)renameViewControllerDidCancel:(RenameViewController *)controller;
@end

@interface RenameViewController : UIViewController <UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate> {
    NSString *_originalTitle;
    UITextField *_textField;
    NSInteger _sessionIndex;
    id<RenameViewControllerDelegate> _delegate;
}

@property (nonatomic, assign) NSInteger sessionIndex;
@property (nonatomic, assign) id<RenameViewControllerDelegate> delegate;

- (id)initWithTitle:(NSString *)title;

@end
