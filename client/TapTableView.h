#import <UIKit/UIKit.h>

@interface TapTableView : UITableView {
    id _tapTarget;
    SEL _tapAction;
}

- (void)setTapTarget:(id)target action:(SEL)action;

@end
