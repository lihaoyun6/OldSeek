#import <UIKit/UIKit.h>

@interface ImageThumbnailView : UIView {
    UIImageView *_imageView;
    UIButton *_deleteButton;
    id _deleteTarget;
    SEL _deleteAction;
}

- (id)initWithImage:(UIImage *)image size:(CGFloat)size;
- (void)setDeleteTarget:(id)target action:(SEL)action;

@end
