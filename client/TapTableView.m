#import "TapTableView.h"

@implementation TapTableView

- (void)setTapTarget:(id)target action:(SEL)action {
    _tapTarget = target;
    _tapAction = action;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    if (_tapTarget != nil && _tapAction != NULL) {
        [_tapTarget performSelector:_tapAction];
    }
}

@end
