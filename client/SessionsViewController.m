#import "SessionsViewController.h"
#import "SessionStore.h"
#import "RenameViewController.h"

@interface UIPopoverController : NSObject
- (id)initWithContentViewController:(UIViewController *)viewController;
- (void)presentPopoverFromRect:(CGRect)rect
                        inView:(UIView *)view
      permittedArrowDirections:(NSUInteger)arrowDirections
                      animated:(BOOL)animated;
- (void)dismissPopoverAnimated:(BOOL)animated;
@property (nonatomic, assign) id delegate;
@end

static UIImage *SessionCheckmarkImage(void) {
    static UIImage *image = nil;
    if (image == nil) {
        UIGraphicsBeginImageContext(CGSizeMake(20.0f, 20.0f));
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGContextSetRGBStrokeColor(ctx, 0.0f, 0.45f, 0.90f, 1.0f);
        CGContextSetLineWidth(ctx, 3.0f);
        CGContextSetLineCap(ctx, kCGLineCapRound);
        CGContextMoveToPoint(ctx, 3.0f, 10.0f);
        CGContextAddLineToPoint(ctx, 8.0f, 15.0f);
        CGContextAddLineToPoint(ctx, 17.0f, 5.0f);
        CGContextStrokePath(ctx);
        image = [UIGraphicsGetImageFromCurrentImageContext() retain];
        UIGraphicsEndImageContext();
    }
    return image;
}

@interface SessionsViewController () <RenameViewControllerDelegate>
@end

@implementation SessionsViewController

@synthesize delegate = _delegate;

- (id)init {
    return [self initWithSidebarMode:NO];
}

- (id)initWithSidebarMode:(BOOL)sidebarMode {
    if ((self = [super init])) {
        _sidebarMode = sidebarMode;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"Sessions", nil);

    if (!_sidebarMode) {
        self.navigationItem.leftBarButtonItem =
            [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", nil)
                                              style:UIBarButtonItemStyleBordered
                                             target:self
                                             action:@selector(done)] autorelease];
    }
    self.navigationItem.rightBarButtonItem =
        [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                       target:self
                                                       action:@selector(newSession)] autorelease];

    _table = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _table.dataSource = self;
    _table.delegate = self;
    _table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_table];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reload)
                                                 name:@"SessionsChanged"
                                               object:nil];
}

- (void)reload {
    [_table reloadData];
}

- (void)done {
    if (_sidebarMode) return;
    [self dismissModalViewControllerAnimated:YES];
}

- (void)newSession {
    [[SessionStore shared] createSession];
    [_delegate sessionsDidChange];
    [_table reloadData];
    if (!_sidebarMode) {
        [self dismissModalViewControllerAnimated:YES];
    }
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)[[SessionStore shared] sessions].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"SessionCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                       reuseIdentifier:identifier] autorelease];
    }

    NSDictionary *session = [[[SessionStore shared] sessions] objectAtIndex:indexPath.row];
    NSString *title = [session objectForKey:@"title"];
    cell.textLabel.text = [title length] > 0 ? title : NSLocalizedString(@"New Session", nil);
    cell.textLabel.font = [UIFont boldSystemFontOfSize:16.0f];

    BOOL current = (indexPath.row == [[SessionStore shared] currentIndex]);
    cell.imageView.image = current ? SessionCheckmarkImage() : nil;
    cell.imageView.contentMode = UIViewContentModeCenter;
    cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[SessionStore shared] selectSessionAtIndex:indexPath.row];
    [_delegate sessionsDidChange];
    [tableView reloadData];
    if (!_sidebarMode) {
        [self dismissModalViewControllerAnimated:YES];
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete) return;
    [[SessionStore shared] deleteSessionAtIndex:indexPath.row];
    [tableView reloadData];
    [_delegate sessionsDidChange];
}

- (void)tableView:(UITableView *)tableView
accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *session = [[[SessionStore shared] sessions] objectAtIndex:indexPath.row];
    RenameViewController *rename = [[RenameViewController alloc]
                                    initWithTitle:[session objectForKey:@"title"]];
    rename.sessionIndex = indexPath.row;
    rename.delegate = self;
    _renamingIndex = indexPath.row;

    UINavigationController *nav = [[UINavigationController alloc]
                                   initWithRootViewController:rename];

    BOOL isPad = [[[UIDevice currentDevice] model] rangeOfString:@"iPad"].location != NSNotFound;
    Class popoverClass = NSClassFromString(@"UIPopoverController");
    if (isPad && popoverClass != nil) {
        NSValue *size = [NSValue valueWithCGSize:CGSizeMake(320.0f, 160.0f)];
        [rename setValue:size forKey:@"contentSizeForViewInPopover"];
        [nav setValue:size forKey:@"contentSizeForViewInPopover"];

        UIPopoverController *popover = [[popoverClass alloc]
                                        initWithContentViewController:nav];
        popover.delegate = self;
        [popover setValue:size forKey:@"popoverContentSize"];
        _renamePopover = [popover retain];

        CGRect anchor = [tableView rectForRowAtIndexPath:indexPath];
        [popover presentPopoverFromRect:anchor
                                 inView:tableView
               permittedArrowDirections:15
                               animated:YES];
        [popover release];
        [nav release];
        [rename release];
        return;
    }

    [self presentModalViewController:nav animated:YES];
    [rename release];
    [nav release];
}

- (void)renameViewController:(RenameViewController *)controller
          didFinishWithTitle:(NSString *)title {
    [[SessionStore shared] renameSessionAtIndex:_renamingIndex title:title];
    [_table reloadData];
    [_delegate sessionsDidChange];
    [self dismissRename];
}

- (void)renameViewControllerDidCancel:(RenameViewController *)controller {
    [self dismissRename];
}

- (void)dismissRename {
    if (_renamePopover != nil) {
        UIPopoverController *popover = (UIPopoverController *)_renamePopover;
        popover.delegate = nil;
        [popover dismissPopoverAnimated:YES];
        [_renamePopover release];
        _renamePopover = nil;
    } else {
        [self dismissModalViewControllerAnimated:YES];
    }
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popover {
    if (popover == _renamePopover) {
        [_renamePopover release];
        _renamePopover = nil;
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    if ([[[UIDevice currentDevice] model] rangeOfString:@"iPad"].location != NSNotFound) {
        return YES;
    }
    return interfaceOrientation == UIInterfaceOrientationPortrait;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_renamePopover != nil) {
        UIPopoverController *popover = (UIPopoverController *)_renamePopover;
        popover.delegate = nil;
        [popover dismissPopoverAnimated:NO];
        [_renamePopover release];
    }
    [_table release];
    [super dealloc];
}

@end
