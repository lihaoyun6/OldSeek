#import <UIKit/UIKit.h>

@class SettingsViewController;

@protocol SettingsViewControllerDelegate <NSObject>
- (void)settingsViewControllerDidFinish;
@end

@interface SettingsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate> {
    UITextField *_keyField;
    UITextField *_modelField;
    id<SettingsViewControllerDelegate> _delegate;
}

@property (nonatomic, assign) id<SettingsViewControllerDelegate> delegate;

@end
