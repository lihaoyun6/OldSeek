#import <UIKit/UIKit.h>

@interface ImageViewController : UIViewController <UIScrollViewDelegate, UINavigationBarDelegate> {
    NSString *_imagePath;
    UIScrollView *_scrollView;
    UIImageView *_imageView;
    UINavigationBar *_navBar;
    UIStatusBarStyle _previousStatusBarStyle;
    BOOL _previousStatusBarHidden;
    BOOL _chromeHidden;
    CGFloat _fillScale;
    CGSize _fittedSize;
    BOOL _syncing;
}

- (id)initWithImagePath:(NSString *)path;

@end
