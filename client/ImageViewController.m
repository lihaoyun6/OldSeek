#import "ImageViewController.h"
#include <math.h>
#include <stdio.h>

@interface ZoomScrollView : UIScrollView {
    id _singleTapTarget;
    SEL _singleTapAction;
}
- (void)setSingleTapTarget:(id)target action:(SEL)action;
@end

@implementation ZoomScrollView

- (void)setSingleTapTarget:(id)target action:(SEL)action {
    _singleTapTarget = target;
    _singleTapAction = action;
}

- (void)handleSingleTap {
    if (_singleTapTarget != nil && _singleTapAction != NULL) {
        [_singleTapTarget performSelector:_singleTapAction];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];

    if ([touches count] != 1 || self.dragging || self.decelerating) return;
    UITouch *touch = [touches anyObject];
    if (touch == nil) return;

    if ([touch tapCount] == 1) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                 selector:@selector(handleSingleTap)
                                                   object:nil];
        [self performSelector:@selector(handleSingleTap)
                   withObject:nil
                   afterDelay:0.3];
        return;
    }

    if ([touch tapCount] != 2) return;

    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(handleSingleTap)
                                               object:nil];

    if (self.zoomScale > self.minimumZoomScale + 0.01f) {
        [self setZoomScale:self.minimumZoomScale animated:YES];
        return;
    }

    UIView *zoomView = nil;
    if ([self.delegate respondsToSelector:@selector(viewForZoomingInScrollView:)]) {
        zoomView = [self.delegate viewForZoomingInScrollView:self];
    }

    /* Fill whichever axis the fitted image does not cover yet. */
    CGFloat newScale = 2.0f;
    if (zoomView != nil &&
        zoomView.bounds.size.width > 0.0f && zoomView.bounds.size.height > 0.0f) {
        CGFloat fillX = self.bounds.size.width / zoomView.bounds.size.width;
        CGFloat fillY = self.bounds.size.height / zoomView.bounds.size.height;
        newScale = MAX(fillX, fillY);
        if (newScale <= 1.01f) newScale = 2.0f;
    }
    if (newScale > self.maximumZoomScale) newScale = self.maximumZoomScale;
    if (newScale <= self.minimumZoomScale + 0.01f) return;

    CGPoint point = zoomView != nil
        ? [touch locationInView:zoomView]
        : [touch locationInView:self];
    CGSize size = self.bounds.size;
    CGRect zoomRect = CGRectMake(point.x - size.width / (2.0f * newScale),
                                 point.y - size.height / (2.0f * newScale),
                                 size.width / newScale,
                                 size.height / newScale);
    [self zoomToRect:zoomRect animated:YES];
}

- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(handleSingleTap)
                                               object:nil];
    [super dealloc];
}

@end

@implementation ImageViewController

- (id)initWithImagePath:(NSString *)path {
    if ((self = [super init])) {
        _imagePath = [path copy];
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _previousStatusBarStyle = [[UIApplication sharedApplication] statusBarStyle];
    _previousStatusBarHidden = [[UIApplication sharedApplication] isStatusBarHidden];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackTranslucent
                                                animated:YES];
    [[UIApplication sharedApplication] setStatusBarHidden:NO animated:NO];
    _chromeHidden = NO;
    _navBar.hidden = NO;
    [self layoutFullScreen];
    [self fitImage];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self layoutFullScreen];
    [self fitImage];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[UIApplication sharedApplication] setStatusBarStyle:_previousStatusBarStyle
                                                animated:YES];
    [[UIApplication sharedApplication] setStatusBarHidden:_previousStatusBarHidden
                                                 animated:YES];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    _scrollView = [[ZoomScrollView alloc] initWithFrame:self.view.bounds];
    _scrollView.backgroundColor = [UIColor blackColor];
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                   UIViewAutoresizingFlexibleHeight;
    _scrollView.delegate = self;
    _scrollView.minimumZoomScale = 1.0f;
    _scrollView.maximumZoomScale = 3.0f;
    _scrollView.bouncesZoom = YES;
    _scrollView.bounces = NO;
    _scrollView.alwaysBounceHorizontal = NO;
    _scrollView.alwaysBounceVertical = NO;
    _scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.showsVerticalScrollIndicator = NO;
    [(ZoomScrollView *)_scrollView setSingleTapTarget:self action:@selector(toggleChrome)];
    [self.view addSubview:_scrollView];

    UIImage *image = nil;
    if ([_imagePath length] > 0) {
        image = [UIImage imageWithContentsOfFile:_imagePath];
    }
    if (image != nil) {
        _imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _imageView.image = image;
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
        _imageView.backgroundColor = [UIColor blackColor];
        [_scrollView addSubview:_imageView];
        [self fitImage];
    }

    _navBar = [[UINavigationBar alloc] initWithFrame:CGRectZero];
    _navBar.barStyle = UIBarStyleBlackTranslucent;
    _navBar.delegate = self;

    UINavigationItem *closeItem = [[UINavigationItem alloc]
                                   initWithTitle:NSLocalizedString(@"Close", nil)];
    UINavigationItem *imageItem = [[UINavigationItem alloc]
                                   initWithTitle:NSLocalizedString(@"Image", nil)];
    [_navBar pushNavigationItem:closeItem animated:NO];
    [_navBar pushNavigationItem:imageItem animated:NO];
    [closeItem release];
    [imageItem release];

    [self.view addSubview:_navBar];
    [self layoutChrome];
}

- (void)layoutChrome {
    CGRect statusFrame = [[UIApplication sharedApplication] statusBarFrame];
    /* In landscape the status bar frame is expressed in screen coordinates and
       is rotated, so its height can be the screen height. Its thickness is the
       smaller of the two dimensions in either orientation. */
    CGFloat statusHeight = MIN(statusFrame.size.width, statusFrame.size.height);
    if (statusHeight <= 0.0f) statusHeight = 20.0f;
    _navBar.frame = CGRectMake(0.0f, statusHeight,
                               self.view.bounds.size.width, 44.0f);
}

- (void)layoutFullScreen {
    UIView *container = self.view.superview;
    UIWindow *window = self.view.window;
    if (container != nil && window != nil) {
        /* Map the whole window into the presentation container's coordinate
           space so the viewer covers the status bar area as well. */
        self.view.frame = [container convertRect:window.bounds fromView:window];
    } else if (container != nil) {
        self.view.frame = container.bounds;
    }
    _scrollView.frame = self.view.bounds;
    [self layoutChrome];
}

- (void)toggleChrome {
    _chromeHidden = !_chromeHidden;
    _navBar.hidden = _chromeHidden;
    [[UIApplication sharedApplication] setStatusBarHidden:_chromeHidden animated:YES];
    if (!_chromeHidden) {
        [self performSelector:@selector(layoutChrome) withObject:nil afterDelay:0.25];
    }
}

- (void)fitImage {
    if (_imageView == nil || _imageView.image == nil) return;
    _scrollView.zoomScale = 1.0f;

    CGSize viewSize = _scrollView.bounds.size;
    CGSize imageSize = _imageView.image.size;
    CGFloat fitScale = 1.0f;
    if (imageSize.width > 0.0f && imageSize.height > 0.0f) {
        CGFloat widthScale = viewSize.width / imageSize.width;
        CGFloat heightScale = viewSize.height / imageSize.height;
        fitScale = MIN(widthScale, heightScale);
        if (fitScale > 1.0f) fitScale = 1.0f;
    }
    CGSize fitted = CGSizeMake(floorf(imageSize.width * fitScale),
                               floorf(imageSize.height * fitScale));
    _imageView.frame = CGRectMake(0.0f, 0.0f, fitted.width, fitted.height);
    _fittedSize = fitted;
    _scrollView.contentSize = fitted;

    CGFloat fillScale = 1.0f;
    if (fitted.width > 0.0f && fitted.height > 0.0f) {
        CGFloat fillX = _scrollView.bounds.size.width / fitted.width;
        CGFloat fillY = _scrollView.bounds.size.height / fitted.height;
        fillScale = MAX(fillX, fillY);
    }
    if (fillScale < 1.0f) fillScale = 1.0f;
    _fillScale = fillScale;
    _scrollView.maximumZoomScale = MAX(3.0f, fillScale * 1.5f);

    [self centerImage];
    [self logZoomGeometry:@"fit"];
}

- (void)centerImage {
    [self syncZoomGeometry];
}

- (CGSize)zoomedContentSize {
    CGFloat scale = _scrollView.zoomScale;
    return CGSizeMake(floorf(_fittedSize.width * scale),
                      floorf(_fittedSize.height * scale));
}

- (void)syncZoomGeometry {
    if (_syncing) return;
    _syncing = YES;

    UIScrollView *scrollView = _scrollView;
    CGSize bounds = scrollView.bounds.size;
    CGSize content = [self zoomedContentSize];

    if (fabs(scrollView.contentSize.width - content.width) > 0.5f ||
        fabs(scrollView.contentSize.height - content.height) > 0.5f) {
        scrollView.contentSize = content;
    }

    CGFloat insetX = content.width < bounds.width
        ? (bounds.width - content.width) * 0.5f : 0.0f;
    CGFloat insetY = content.height < bounds.height
        ? (bounds.height - content.height) * 0.5f : 0.0f;
    scrollView.contentInset = UIEdgeInsetsMake(insetY, insetX, insetY, insetX);

    CGFloat minX, maxX, minY, maxY;
    if (scrollView.zoomScale < _fillScale - 0.01f) {
        /* Below the fill scale the image still has margins on at least one
           side. Lock it in the middle instead of allowing a small pinch to
           turn into free panning. */
        minX = maxX = (content.width - bounds.width) * 0.5f;
        minY = maxY = (content.height - bounds.height) * 0.5f;
    } else {
        /* Never let an edge move inside the viewport: at most the image can
           sit flush with the screen edge. */
        minX = -insetX;
        maxX = content.width - bounds.width + insetX;
        if (maxX < minX) maxX = minX;
        minY = -insetY;
        maxY = content.height - bounds.height + insetY;
        if (maxY < minY) maxY = minY;
    }

    CGPoint offset = scrollView.contentOffset;
    CGFloat x = offset.x;
    CGFloat y = offset.y;
    if (x < minX) x = minX;
    if (x > maxX) x = maxX;
    if (y < minY) y = minY;
    if (y > maxY) y = maxY;

    if (fabs(x - offset.x) > 0.5f || fabs(y - offset.y) > 0.5f) {
        [scrollView setContentOffset:CGPointMake(x, y) animated:NO];
    }

    _syncing = NO;
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return _imageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    [self syncZoomGeometry];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self syncZoomGeometry];
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView
                       withView:(UIView *)view
                        atScale:(float)scale {
    [self syncZoomGeometry];
    [self logZoomGeometry:@"endZoom"];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView
                  willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        [self syncZoomGeometry];
        [self logZoomGeometry:@"endDrag"];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self syncZoomGeometry];
    [self logZoomGeometry:@"endDecel"];
}

- (void)logZoomGeometry:(NSString *)tag {
    CGSize content = [self zoomedContentSize];
    UIEdgeInsets inset = _scrollView.contentInset;
    NSString *message = [NSString stringWithFormat:
        @"%@ fitted=%.0fx%.0f fill=%.2f zoom=%.2f content=%.0fx%.0f bounds=%.0fx%.0f inset=%.1f/%.1f/%.1f/%.1f offset=%.0f,%.0f",
        tag, _fittedSize.width, _fittedSize.height, _fillScale,
        _scrollView.zoomScale, content.width, content.height,
        _scrollView.bounds.size.width, _scrollView.bounds.size.height,
        inset.top, inset.left, inset.bottom, inset.right,
        _scrollView.contentOffset.x, _scrollView.contentOffset.y];
    FILE *file = fopen("/var/mobile/oldseek.log", "a");
    if (file != NULL) {
        fprintf(file, "[viewer] %s\n", [message UTF8String]);
        fclose(file);
    }
}

- (BOOL)navigationBar:(UINavigationBar *)navigationBar
        shouldPopItem:(UINavigationItem *)item {
    [self dismissModalViewControllerAnimated:YES];
    return NO;
}

- (void)close {
    [self dismissModalViewControllerAnimated:YES];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    if ([[[UIDevice currentDevice] model] rangeOfString:@"iPad"].location != NSNotFound) {
        return YES;
    }
    return interfaceOrientation == UIInterfaceOrientationPortrait;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation
                                            duration:duration];
    [self layoutFullScreen];
    [self fitImage];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    [self layoutFullScreen];
    [self fitImage];
}

- (void)dealloc {
    [_imagePath release];
    [_scrollView release];
    [_imageView release];
    [_navBar release];
    [super dealloc];
}

@end
