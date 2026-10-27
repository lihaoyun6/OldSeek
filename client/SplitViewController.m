#import "SplitViewController.h"
#import "ChatViewController.h"

/* Draws the four rounded inner corners as small black patches on top of the
   panes. The previous implementation masked both entire panes with a
   CAShapeLayer, which forced off-screen compositing of the whole split view on
   every frame and made scrolling sluggish on the iPad 1. */
@interface SplitCornerOverlay : UIView {
    CGFloat _dividerWidth;
    CGFloat _radius;
}
- (void)setDividerWidth:(CGFloat)dividerWidth radius:(CGFloat)radius;
@end

@implementation SplitCornerOverlay

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)setDividerWidth:(CGFloat)dividerWidth radius:(CGFloat)radius {
    if (_dividerWidth == dividerWidth && _radius == radius) return;
    _dividerWidth = dividerWidth;
    _radius = radius;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGFloat r = _radius;
    CGFloat h = self.bounds.size.height;
    if (r <= 0.0f || h <= 0.0f) return;

    CGFloat left = r;                 /* right edge of the left pane */
    CGFloat right = r + _dividerWidth; /* left edge of the right pane */

    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetRGBFillColor(ctx, 0.0f, 0.0f, 0.0f, 1.0f);

    /* Left pane, top-right corner: square minus quarter circle. */
    CGContextAddRect(ctx, CGRectMake(left - r, 0.0f, r, r));
    CGContextMoveToPoint(ctx, left - r, r);
    CGContextAddArc(ctx, left - r, r, r, -M_PI_2, 0.0f, 0);
    CGContextClosePath(ctx);

    /* Left pane, bottom-right corner. */
    CGContextAddRect(ctx, CGRectMake(left - r, h - r, r, r));
    CGContextMoveToPoint(ctx, left - r, h - r);
    CGContextAddArc(ctx, left - r, h - r, r, 0.0f, M_PI_2, 0);
    CGContextClosePath(ctx);

    /* Right pane, top-left corner. */
    CGContextAddRect(ctx, CGRectMake(right, 0.0f, r, r));
    CGContextMoveToPoint(ctx, right + r, r);
    CGContextAddArc(ctx, right + r, r, r, M_PI, 1.5 * M_PI, 0);
    CGContextClosePath(ctx);

    /* Right pane, bottom-left corner. */
    CGContextAddRect(ctx, CGRectMake(right, h - r, r, r));
    CGContextMoveToPoint(ctx, right + r, h - r);
    CGContextAddArc(ctx, right + r, h - r, r, 0.5 * M_PI, M_PI, 0);
    CGContextClosePath(ctx);

    CGContextEOFillPath(ctx);
}

@end

@interface SplitViewController () <ChatViewControllerSplitDelegate>
@end

@implementation SplitViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _sidebarVisible = YES;
    self.wantsFullScreenLayout = NO;
    self.view.backgroundColor = [UIColor blackColor];

    SessionsViewController *sessions =
        [[SessionsViewController alloc] initWithSidebarMode:YES];
    sessions.delegate = self;
    _sessionsNav = [[UINavigationController alloc] initWithRootViewController:sessions];
    _sessionsViewController = sessions;
    [sessions release];
    _sessionsNav.navigationBar.barStyle = UIBarStyleDefault;
    _sessionsNav.wantsFullScreenLayout = NO;

    ChatViewController *chat = [[ChatViewController alloc] initWithSplitMode:YES];
    chat.splitDelegate = self;
    _chatNav = [[UINavigationController alloc] initWithRootViewController:chat];
    _chatViewController = chat;
    [chat release];
    _chatNav.navigationBar.barStyle = UIBarStyleDefault;
    _chatNav.wantsFullScreenLayout = NO;

    _divider = [[UIView alloc] initWithFrame:CGRectZero];
    _divider.backgroundColor = [UIColor blackColor];
    _divider.autoresizingMask = UIViewAutoresizingNone;

    _sessionsNav.view.autoresizingMask = UIViewAutoresizingNone;
    _chatNav.view.autoresizingMask = UIViewAutoresizingNone;

    [self.view addSubview:_sessionsNav.view];
    [self.view addSubview:_divider];
    [self.view addSubview:_chatNav.view];

    _cornerOverlay = [[SplitCornerOverlay alloc] initWithFrame:CGRectZero];
    _cornerOverlay.autoresizingMask = UIViewAutoresizingNone;
    [self.view addSubview:_cornerOverlay];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(statusBarOrientationChanged:)
                                                 name:UIApplicationDidChangeStatusBarOrientationNotification
                                               object:nil];

    [self layoutViews];
}

- (void)layoutViews {
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;

    CGFloat leftWidth = _sidebarVisible ? 320.0f : 0.0f;
    CGFloat dividerWidth = _sidebarVisible ? 1.0f : 0.0f;

    _sessionsNav.view.hidden = !_sidebarVisible;
    _divider.hidden = !_sidebarVisible;

    _sessionsNav.view.frame = CGRectMake(0.0f, 0.0f, leftWidth, height);
    _divider.frame = CGRectMake(leftWidth, 0.0f, dividerWidth, height);
    _chatNav.view.frame = CGRectMake(leftWidth + dividerWidth, 0.0f,
                                     width - leftWidth - dividerWidth, height);

    CGFloat radius = 4.0f;
    _cornerOverlay.hidden = !_sidebarVisible;
    if (_sidebarVisible) {
        _cornerOverlay.frame = CGRectMake(leftWidth - radius, 0.0f,
                                          dividerWidth + 2.0f * radius, height);
        [(SplitCornerOverlay *)_cornerOverlay setDividerWidth:dividerWidth
                                                       radius:radius];
        [self.view bringSubviewToFront:_cornerOverlay];
    }
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [self performSelector:@selector(relayoutAfterTransition)
               withObject:nil
               afterDelay:0.15];
    [self performSelector:@selector(relayoutAfterTransition)
               withObject:nil
               afterDelay:0.5];
}

- (void)statusBarOrientationChanged:(NSNotification *)notification {
    [self performSelector:@selector(relayoutAfterTransition)
               withObject:nil
               afterDelay:0.6];
}

- (void)relayoutAfterTransition {
    [self layoutViews];
    [_chatViewController relayout];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self layoutViews];
    [_sessionsNav viewWillAppear:animated];
    [_chatNav viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [_sessionsNav viewDidAppear:animated];
    [_chatNav viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_sessionsNav viewWillDisappear:animated];
    [_chatNav viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [_sessionsNav viewDidDisappear:animated];
    [_chatNav viewDidDisappear:animated];
}

- (void)sessionsDidChange {
    [_chatViewController sessionsDidChange];
    [_sessionsViewController reload];
}

- (void)chatViewControllerDidTapSessions {
    _sidebarVisible = !_sidebarVisible;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.25];
    [self layoutViews];
    [_chatViewController relayout];
    [UIView commitAnimations];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [_sessionsNav willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [_chatNav willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation
                                            duration:duration];
    [self layoutViews];
    [_chatViewController relayout];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    [self layoutViews];
    [_chatViewController relayout];
    [_sessionsNav didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    [_chatNav didRotateFromInterfaceOrientation:fromInterfaceOrientation];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_sessionsNav release];
    [_chatNav release];
    [_divider release];
    [_cornerOverlay release];
    [super dealloc];
}

@end
