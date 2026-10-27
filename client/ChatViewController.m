#import "ChatViewController.h"
#import "MessageCell.h"
#import "SettingsViewController.h"
#import "SessionsViewController.h"
#import "SessionStore.h"
#import "TapTableView.h"
#import "ChatBackgroundView.h"
#import "ChatInputBarView.h"
#import "ImageThumbnailView.h"
#import "ImageViewController.h"
#import <QuartzCore/QuartzCore.h>
#include <math.h>
#include <stdlib.h>
#include <time.h>

static const CGFloat kInputBarBaseHeight = 44.0f;
static const CGFloat kThumbnailRowHeight = 64.0f;
static const CGFloat kInputFieldMinHeight = 34.0f;
static const CGFloat kInputFieldMaxHeight = 100.0f;
static const NSInteger kMaxPendingImages = 4;

/* iPhoneOS 3.1.3 SDK predates the iPad, so UIPopoverController is declared
   here and instantiated via NSClassFromString at runtime on iPad. */
@interface UIPopoverController : NSObject
- (id)initWithContentViewController:(UIViewController *)viewController;
- (void)presentPopoverFromRect:(CGRect)rect
                        inView:(UIView *)view
      permittedArrowDirections:(NSUInteger)arrowDirections
                      animated:(BOOL)animated;
- (void)dismissPopoverAnimated:(BOOL)animated;
@property (nonatomic, assign) id delegate;
@end

@interface CameraButton : UIButton {
    UIImage *_cameraImage;
}
- (void)setCameraImage:(UIImage *)image;
@end

@implementation CameraButton

- (void)setCameraImage:(UIImage *)image {
    if (_cameraImage != image) {
        [_cameraImage release];
        _cameraImage = [image retain];
        [self setNeedsDisplay];
    }
}

- (void)drawRect:(CGRect)rect {
    if (_cameraImage == nil) return;
    CGSize size = _cameraImage.size;
    CGRect target = CGRectMake(floorf((self.bounds.size.width - size.width) / 2.0f),
                               floorf((self.bounds.size.height - size.height) / 2.0f),
                               size.width, size.height);
    if (!self.enabled) {
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGContextSetAlpha(ctx, 0.45f);
    }
    [_cameraImage drawInRect:target];
}

- (void)dealloc {
    [_cameraImage release];
    [super dealloc];
}

@end

@implementation ChatViewController

@synthesize splitDelegate = _splitDelegate;

+ (UIImage *)sendButtonImage {
    CGSize size = CGSizeMake(62.0f, 30.0f);
    UIGraphicsBeginImageContext(size);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    CGRect r = CGRectMake(0.5f, 0.5f, size.width - 1.0f, size.height - 1.0f);
    CGFloat radius = (size.height - 1.0f) / 2.0f;
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, CGRectGetMinX(r) + radius, CGRectGetMinY(r));
    CGPathAddLineToPoint(path, NULL, CGRectGetMaxX(r) - radius, CGRectGetMinY(r));
    CGPathAddArcToPoint(path, NULL, CGRectGetMaxX(r), CGRectGetMinY(r), CGRectGetMaxX(r), CGRectGetMinY(r) + radius, radius);
    CGPathAddLineToPoint(path, NULL, CGRectGetMaxX(r), CGRectGetMaxY(r) - radius);
    CGPathAddArcToPoint(path, NULL, CGRectGetMaxX(r), CGRectGetMaxY(r), CGRectGetMaxX(r) - radius, CGRectGetMaxY(r), radius);
    CGPathAddLineToPoint(path, NULL, CGRectGetMinX(r) + radius, CGRectGetMaxY(r));
    CGPathAddArcToPoint(path, NULL, CGRectGetMinX(r), CGRectGetMaxY(r), CGRectGetMinX(r), CGRectGetMaxY(r) - radius, radius);
    CGPathAddLineToPoint(path, NULL, CGRectGetMinX(r), CGRectGetMinY(r) + radius);
    CGPathAddArcToPoint(path, NULL, CGRectGetMinX(r), CGRectGetMinY(r), CGRectGetMinX(r) + radius, CGRectGetMinY(r), radius);
    CGPathCloseSubpath(path);

    CGContextSaveGState(ctx);
    CGContextAddPath(ctx, path);
    CGContextClip(ctx);

    CGFloat colors[8] = { 0.38f, 0.68f, 0.98f, 1.0f, 0.08f, 0.38f, 0.84f, 1.0f };
    CGFloat locations[2] = { 0.0f, 1.0f };
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient = CGGradientCreateWithColorComponents(space, colors, locations, 2);
    CGContextDrawLinearGradient(ctx, gradient, CGPointMake(0, 0), CGPointMake(0, size.height), 0);
    CGGradientRelease(gradient);

    CGFloat shine[8] = { 1.0f, 1.0f, 1.0f, 0.30f, 1.0f, 1.0f, 1.0f, 0.0f };
    CGGradientRef gloss = CGGradientCreateWithColorComponents(space, shine, locations, 2);
    CGContextDrawLinearGradient(ctx, gloss, CGPointMake(0, 1.0f), CGPointMake(0, size.height * 0.55f), 0);
    CGGradientRelease(gloss);
    CGColorSpaceRelease(space);
    CGContextRestoreGState(ctx);

    CGContextAddPath(ctx, path);
    CGContextSetLineWidth(ctx, 1.0f);
    CGContextSetRGBStrokeColor(ctx, 0.05f, 0.28f, 0.68f, 1.0f);
    CGContextStrokePath(ctx);
    CGPathRelease(path);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (id)init {
    return [self initWithSplitMode:NO];
}

- (id)initWithSplitMode:(BOOL)splitMode {
    if ((self = [super init])) {
        _splitMode = splitMode;
        _session = [[[SessionStore shared] currentSession] retain];
        _messages = [[_session objectForKey:@"messages"] retain];
        _pendingImages = [[NSMutableArray alloc] init];
        _thumbnailViews = [[NSMutableArray alloc] init];
        _imageCache = [[NSMutableDictionary alloc] init];
        _scrollToBottomOnAppear = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self updateNavigationTitle];
    self.view.backgroundColor = [UIColor colorWithRed:220.0f / 255.0f
                                                green:226.0f / 255.0f
                                                 blue:236.0f / 255.0f
                                                alpha:1.0f];

    ChatBackgroundView *background = [[ChatBackgroundView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:background];
    [background release];

    self.navigationItem.leftBarButtonItem =
        [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Sessions", nil)
                                          style:UIBarButtonItemStyleBordered
                                         target:self
                                         action:@selector(openSessions)] autorelease];
    self.navigationItem.rightBarButtonItem =
        [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Settings", nil)
                                          style:UIBarButtonItemStyleBordered
                                         target:self
                                         action:@selector(openSettings)] autorelease];

    TapTableView *table = [[TapTableView alloc] initWithFrame:CGRectZero
                                                        style:UITableViewStylePlain];
    table.dataSource = self;
    table.delegate = self;
    table.separatorStyle = UITableViewCellSeparatorStyleNone;
    table.backgroundColor = [UIColor clearColor];
    [table setTapTarget:self action:@selector(dismissKeyboard)];
    table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _table = table;
    [self.view addSubview:_table];

    _inputBar = [[ChatInputBarView alloc] initWithFrame:CGRectZero];
    _inputBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:_inputBar];

    _thumbnailContainer = [[UIView alloc] initWithFrame:CGRectZero];
    _thumbnailContainer.backgroundColor = [UIColor clearColor];
    [_inputBar addSubview:_thumbnailContainer];

    CameraButton *cameraButton = [CameraButton buttonWithType:UIButtonTypeCustom];
    cameraButton.opaque = NO;
    cameraButton.backgroundColor = [UIColor clearColor];
    [cameraButton setCameraImage:[UIImage imageNamed:@"PhotoButton.png"]];
    [cameraButton addTarget:self action:@selector(openImagePicker)
           forControlEvents:UIControlEventTouchUpInside];
    _cameraButton = cameraButton;
    [_inputBar addSubview:_cameraButton];

    _inputFieldBackground = [[UIView alloc] initWithFrame:CGRectZero];
    _inputFieldBackground.backgroundColor = [UIColor whiteColor];
    _inputFieldBackground.opaque = NO;
    _inputFieldBackground.layer.cornerRadius = kInputFieldMinHeight / 2.0f;
    _inputFieldBackground.layer.masksToBounds = YES;
    _inputFieldBackground.layer.borderWidth = 1.0f;
    _inputFieldBackground.layer.borderColor =
        [UIColor colorWithRed:0.55f green:0.57f blue:0.60f alpha:1.0f].CGColor;
    [_inputBar addSubview:_inputFieldBackground];

    _inputPlaceholder = [[UILabel alloc] initWithFrame:CGRectZero];
    _inputPlaceholder.text = NSLocalizedString(@"Type a message", nil);
    _inputPlaceholder.font = [UIFont systemFontOfSize:15.0f];
    _inputPlaceholder.textColor = [UIColor colorWithWhite:0.55f alpha:1.0f];
    _inputPlaceholder.backgroundColor = [UIColor clearColor];
    _inputPlaceholder.userInteractionEnabled = NO;
    [_inputBar addSubview:_inputPlaceholder];

    _input = [[UITextView alloc] initWithFrame:CGRectZero];
    _input.delegate = self;
    _input.font = [UIFont systemFontOfSize:15.0f];
    _input.textColor = [UIColor blackColor];
    _input.backgroundColor = [UIColor clearColor];
    _input.opaque = NO;
    _input.scrollEnabled = NO;
    _input.showsVerticalScrollIndicator = NO;
    _input.autocorrectionType = UITextAutocorrectionTypeNo;
    _input.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _input.returnKeyType = UIReturnKeyDefault;
    _input.dataDetectorTypes = UIDataDetectorTypeNone;
    [_inputBar addSubview:_input];

    _sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_sendButton setBackgroundImage:[ChatViewController sendButtonImage]
                           forState:UIControlStateNormal];
    [_sendButton setTitle:NSLocalizedString(@"Send", nil) forState:UIControlStateNormal];
    [_sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _sendButton.titleLabel.font = [UIFont boldSystemFontOfSize:15.0f];
    [_sendButton addTarget:self action:@selector(send) forControlEvents:UIControlEventTouchUpInside];
    [_inputBar addSubview:_sendButton];

    [self layoutViews];
    [_table reloadData];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(keyboardWillShow:)
               name:UIKeyboardWillShowNotification object:nil];
    [nc addObserver:self selector:@selector(keyboardWillHide:)
               name:UIKeyboardWillHideNotification object:nil];
    [nc addObserver:self selector:@selector(dismissKeyboard)
               name:@"MessageCellTapped" object:nil];
    [nc addObserver:self selector:@selector(sessionsChanged)
               name:@"SessionsChanged" object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self layoutViews];
    /* The split view sizes this pane after -viewDidLoad, which changes the
       maximum bubble width. Recompute row heights for the current width. */
    [_table reloadData];
    if (!_restoreContentOffset && _scrollToBottomOnAppear) {
        [self scrollToBottom];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self layoutViews];
    if (_restoreContentOffset) {
        _restoreContentOffset = NO;
        CGFloat maxY = _table.contentSize.height - _table.bounds.size.height;
        if (maxY < 0.0f) maxY = 0.0f;
        CGPoint offset = _savedContentOffset;
        if (offset.y > maxY) offset.y = maxY;
        if (offset.y < 0.0f) offset.y = 0.0f;
        [_table setContentOffset:offset animated:NO];
    } else if (_scrollToBottomOnAppear) {
        [self scrollToBottom];
        _scrollToBottomOnAppear = NO;
    }
    if (!_openedSettings) {
        _openedSettings = YES;
        NSString *key = [[NSUserDefaults standardUserDefaults] stringForKey:@"api_key"];
        if ([key length] == 0) [self openSettings];
    }
}

- (CGFloat)desiredInputFieldHeight {
    CGFloat width = self.view.bounds.size.width - 46.0f - 78.0f - 12.0f;
    if (width < 20.0f) width = 20.0f;
    UIFont *font = _input.font ? _input.font : [UIFont systemFontOfSize:15.0f];
    CGFloat lineHeight = ceilf([@" " sizeWithFont:font].height);

    CGFloat totalHeight = 0.0f;
    NSArray *lines = [_input.text componentsSeparatedByString:@"\n"];
    NSString *line;
    for (line in lines) {
        NSString *measure = [line length] > 0 ? line : @" ";
        CGSize oneLine = [measure sizeWithFont:font];
        CGSize wrapped = [measure sizeWithFont:font
                             constrainedToSize:CGSizeMake(width, 10000.0f)
                                 lineBreakMode:UILineBreakModeWordWrap];
        if (oneLine.width > width &&
            wrapped.height <= ceilf(oneLine.height) + 1.0f) {
            wrapped = [measure sizeWithFont:font
                          constrainedToSize:CGSizeMake(width, 10000.0f)
                              lineBreakMode:UILineBreakModeCharacterWrap];
        }
        totalHeight += wrapped.height;
    }

    CGFloat height;
    if (totalHeight <= lineHeight + 0.5f) {
        height = kInputFieldMinHeight;
    } else {
        height = ceilf(totalHeight) + 18.0f;
    }
    if (height > kInputFieldMaxHeight) height = kInputFieldMaxHeight;
    return height;
}

- (void)layoutViews {
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;

    CGFloat maxTextWidth = width * 0.75f;
    if (maxTextWidth < 240.0f) maxTextWidth = 240.0f;
    if (maxTextWidth > 560.0f) maxTextWidth = 560.0f;
    [MessageCell setMaxTextWidth:maxTextWidth];

    CGFloat fieldHeight = [self desiredInputFieldHeight];
    CGFloat bottomRowHeight = MAX(kInputBarBaseHeight, fieldHeight + 14.0f);
    CGFloat imagesHeight = ([_pendingImages count] > 0) ? kThumbnailRowHeight : 0.0f;
    CGFloat barHeight = imagesHeight + bottomRowHeight;
    CGFloat available = height - _keyboardHeight;
    CGFloat tableHeight = available - barHeight;
    if (tableHeight < 0.0f) tableHeight = 0.0f;

    CGFloat fieldWidth = width - 46.0f - 78.0f;
    if (fieldWidth < 40.0f) fieldWidth = 40.0f;
    CGFloat fieldX = 46.0f;
    CGFloat fieldY = barHeight - 7.0f - fieldHeight;

    _table.frame = CGRectMake(0, 0, width, tableHeight);
    _inputBar.frame = CGRectMake(0, available - barHeight, width, barHeight);
    _thumbnailContainer.frame = CGRectMake(0, 0, width, imagesHeight);

    _inputFieldBackground.frame = CGRectMake(fieldX, fieldY, fieldWidth, fieldHeight);
    BOOL capsule = (fieldHeight <= kInputFieldMinHeight + 0.5f);
    _inputFieldBackground.layer.cornerRadius = capsule ? fieldHeight / 2.0f : 8.0f;

    CGFloat padX = 10.0f;
    CGFloat padY = 8.0f;
    CGFloat textAreaWidth = fieldWidth - 2.0f * padX;
    if (textAreaWidth < 20.0f) textAreaWidth = 20.0f;
    CGFloat textAreaHeight = fieldHeight - 2.0f * padY;
    if (textAreaHeight < 18.0f) textAreaHeight = 18.0f;

    _inputPlaceholder.hidden = ([_input.text length] > 0);
    _inputPlaceholder.frame = CGRectMake(fieldX + padX, fieldY + padY,
                                         textAreaWidth, 18.0f);

    if ([_input.text length] == 0) {
        _input.frame = CGRectMake(fieldX + padX, fieldY + padY,
                                  textAreaWidth, textAreaHeight);
    } else {
        _input.frame = CGRectMake(fieldX + padX - 8.0f, fieldY + padY - 8.0f,
                                  textAreaWidth + 16.0f, textAreaHeight + 16.0f);
    }
    _input.scrollEnabled = (fieldHeight >= kInputFieldMaxHeight - 0.5f);
    if (_input.scrollEnabled) {
        [_input scrollRangeToVisible:_input.selectedRange];
    } else {
        [_input setContentOffset:CGPointZero];
        if ([_input.text length] == 0) {
            _input.selectedRange = NSMakeRange(0, 0);
        }
    }

    CGFloat cameraSize = 30.0f;
    CGFloat cameraY = fieldY + (fieldHeight - cameraSize) / 2.0f + 2.0f;
    _cameraButton.frame = CGRectMake(8.0f, cameraY, cameraSize, cameraSize);
    _cameraButton.enabled = ([_pendingImages count] < kMaxPendingImages);
    CGFloat sendY = fieldY + (fieldHeight - 30.0f) / 2.0f;
    _sendButton.frame = CGRectMake(width - 70.0f, sendY, 62.0f, 30.0f);
}

- (void)relayout {
    [self layoutViews];
    [_table reloadData];

    CGFloat maxY = _table.contentSize.height - _table.bounds.size.height;
    if (maxY < 0.0f) maxY = 0.0f;
    CGPoint offset = _table.contentOffset;
    if (offset.y > maxY) offset.y = maxY;
    if (offset.y < 0.0f) offset.y = 0.0f;
    [_table setContentOffset:offset animated:NO];
}

- (void)layoutThumbnails {
    CGFloat x = 12.0f;
    ImageThumbnailView *view;
    for (view in _thumbnailViews) {
        view.frame = CGRectMake(x, 0.0f, view.frame.size.width, view.frame.size.height);
        x += view.frame.size.width + 6.0f;
    }
}

- (void)keyboardWillShow:(NSNotification *)note {
    NSValue *value = [[note userInfo] objectForKey:UIKeyboardBoundsUserInfoKey];
    _keyboardHeight = [value CGRectValue].size.height;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.25];
    [self layoutViews];
    [UIView commitAnimations];
    [self scrollToBottom];
}

- (void)keyboardWillHide:(NSNotification *)note {
    _keyboardHeight = 0;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.25];
    [self layoutViews];
    [UIView commitAnimations];
}

- (void)openSettings {
    [_input resignFirstResponder];

    SettingsViewController *settings = [[SettingsViewController alloc] init];
    settings.delegate = self;

    BOOL isPad = [[[UIDevice currentDevice] model] rangeOfString:@"iPad"].location != NSNotFound;
    Class popoverClass = NSClassFromString(@"UIPopoverController");
    if (isPad && popoverClass != nil) {
        NSValue *popoverSize = [NSValue valueWithCGSize:CGSizeMake(420.0f, 360.0f)];
        [settings setValue:popoverSize forKey:@"contentSizeForViewInPopover"];

        UINavigationController *nav = [[UINavigationController alloc]
                                       initWithRootViewController:settings];
        [settings release];
        [nav setValue:popoverSize forKey:@"contentSizeForViewInPopover"];

        UIPopoverController *popover = [[popoverClass alloc]
                                        initWithContentViewController:nav];
        popover.delegate = self;
        [popover setValue:popoverSize forKey:@"popoverContentSize"];
        _settingsPopover = [popover retain];

        UIView *anchorView = self.navigationController.navigationBar;
        if (anchorView == nil) anchorView = self.view;
        CGRect anchor = CGRectMake(anchorView.bounds.size.width - 60.0f,
                                   anchorView.bounds.size.height - 22.0f,
                                   60.0f, 22.0f);
        [popover presentPopoverFromRect:anchor
                                 inView:anchorView
               permittedArrowDirections:1
                               animated:YES];
        [popover release];
        [nav release];
        return;
    }

    settings.wantsFullScreenLayout = NO;
    UINavigationController *nav = [[UINavigationController alloc]
                                   initWithRootViewController:settings];
    nav.wantsFullScreenLayout = NO;
    [self presentModalViewController:nav animated:YES];
    [settings release];
    [nav release];
}

- (void)settingsViewControllerDidFinish {
    [self dismissSettings];
}

- (void)dismissSettings {
    if (_settingsPopover != nil) {
        UIPopoverController *popover = (UIPopoverController *)_settingsPopover;
        popover.delegate = nil;
        [popover dismissPopoverAnimated:YES];
        [_settingsPopover release];
        _settingsPopover = nil;
    } else {
        [self dismissModalViewControllerAnimated:YES];
    }
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popover {
    if (popover == _settingsPopover) {
        [_settingsPopover release];
        _settingsPopover = nil;
    }
    if (popover == _imagePickerPopover) {
        [_imagePickerPopover release];
        _imagePickerPopover = nil;
    }
}

- (void)openSessions {
    if (_splitMode && _splitDelegate != nil) {
        [_splitDelegate chatViewControllerDidTapSessions];
        return;
    }

    [_input resignFirstResponder];
    SessionsViewController *sessions = [[SessionsViewController alloc] init];
    sessions.wantsFullScreenLayout = NO;
    sessions.delegate = self;
    UINavigationController *nav = [[UINavigationController alloc]
                                   initWithRootViewController:sessions];
    nav.wantsFullScreenLayout = NO;
    [self presentModalViewController:nav animated:YES];
    [sessions release];
    [nav release];
}

#pragma mark - Images

- (void)openImagePicker {
    [_input resignFirstResponder];

    UIImagePickerControllerSourceType source = UIImagePickerControllerSourceTypePhotoLibrary;
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        source = UIImagePickerControllerSourceTypeCamera;
    }
    if (![UIImagePickerController isSourceTypeAvailable:source]) {
        UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:nil
                                                        message:NSLocalizedString(@"Unable to open the camera or photo library", nil)
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                              otherButtonTitles:nil] autorelease];
        [alert show];
        return;
    }

    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = source;
    picker.allowsEditing = NO;
    picker.delegate = self;

    BOOL isPad = [[[UIDevice currentDevice] model] rangeOfString:@"iPad"].location != NSNotFound;
    Class popoverClass = NSClassFromString(@"UIPopoverController");
    if (isPad && popoverClass != nil &&
        source == UIImagePickerControllerSourceTypePhotoLibrary) {
        UIPopoverController *popover = [[popoverClass alloc]
                                        initWithContentViewController:picker];
        popover.delegate = self;
        _imagePickerPopover = [popover retain];
        [popover presentPopoverFromRect:_cameraButton.frame
                                 inView:_inputBar
               permittedArrowDirections:15
                               animated:YES];
        [popover release];
        [picker release];
        return;
    }

    [self presentModalViewController:picker animated:YES];
    [picker release];
}

- (void)imagePickerController:(UIImagePickerController *)picker
        didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
    [self dismissImagePicker];
    if (image == nil) return;

    if ([_pendingImages count] >= kMaxPendingImages) {
        UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:nil
                                                        message:NSLocalizedString(@"You can attach up to 4 images per message", nil)
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                              otherButtonTitles:nil] autorelease];
        [alert show];
        return;
    }

    UIImage *resized = [self resizedImage:image maxDimension:800.0f];
    if (resized != nil) [self addPendingImage:resized];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self dismissImagePicker];
}

- (void)dismissImagePicker {
    if (_imagePickerPopover != nil) {
        UIPopoverController *popover = (UIPopoverController *)_imagePickerPopover;
        popover.delegate = nil;
        [popover dismissPopoverAnimated:YES];
        [_imagePickerPopover release];
        _imagePickerPopover = nil;
    } else {
        [self dismissModalViewControllerAnimated:YES];
    }
}

- (UIImage *)resizedImage:(UIImage *)image maxDimension:(CGFloat)maxDimension {
    CGSize size = image.size;
    if (size.width < 1.0f || size.height < 1.0f) return nil;

    CGFloat scale = 1.0f;
    if (size.width > maxDimension || size.height > maxDimension) {
        scale = maxDimension / MAX(size.width, size.height);
    }
    CGSize target = CGSizeMake(floorf(size.width * scale),
                               floorf(size.height * scale));
    if (target.width < 1.0f) target.width = 1.0f;
    if (target.height < 1.0f) target.height = 1.0f;

    UIGraphicsBeginImageContext(target);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetRGBFillColor(ctx, 1.0f, 1.0f, 1.0f, 1.0f);
    CGContextFillRect(ctx, CGRectMake(0.0f, 0.0f, target.width, target.height));
    [image drawInRect:CGRectMake(0.0f, 0.0f, target.width, target.height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

- (void)addPendingImage:(UIImage *)image {
    [_pendingImages addObject:image];

    ImageThumbnailView *thumbnail = [[ImageThumbnailView alloc] initWithImage:image
                                                                        size:52.0f];
    [thumbnail setDeleteTarget:self action:@selector(deleteThumbnail:)];
    [_thumbnailContainer addSubview:thumbnail];
    [_thumbnailViews addObject:thumbnail];
    [thumbnail release];

    [self layoutThumbnails];
    [self updateInputBarHeightAnimated:YES];
}

- (void)deleteThumbnail:(ImageThumbnailView *)thumbnail {
    [thumbnail retain];
    NSInteger index = (NSInteger)[_thumbnailViews indexOfObject:thumbnail];
    if (index == NSNotFound) {
        [thumbnail release];
        return;
    }

    [_thumbnailViews removeObjectAtIndex:index];
    [_pendingImages removeObjectAtIndex:index];
    [thumbnail removeFromSuperview];

    [self layoutThumbnails];
    [self updateInputBarHeightAnimated:YES];
    [thumbnail release];
}

- (void)clearPendingImages {
    ImageThumbnailView *thumbnail;
    for (thumbnail in _thumbnailViews) {
        [thumbnail removeFromSuperview];
    }
    [_thumbnailViews removeAllObjects];
    [_pendingImages removeAllObjects];
}

- (void)updateInputBarHeightAnimated:(BOOL)animated {
    CGFloat maxY = _table.contentSize.height - _table.bounds.size.height;
    if (maxY < 0.0f) maxY = 0.0f;
    BOOL followBottom = (_table.contentOffset.y >= maxY - 40.0f);

    if (animated) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.2];
    }
    [self layoutViews];
    if (animated) [UIView commitAnimations];
    if (followBottom) [self scrollToBottom];
}

- (NSString *)imagesDirectory {
    NSString *base = [SessionStore dataDirectory];
    if (base == nil) return nil;
    NSString *directory = [base stringByAppendingPathComponent:@"images"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:directory]) {
        [fm createDirectoryAtPath:directory attributes:nil];
    }
    return directory;
}

- (NSDictionary *)savePendingImage:(UIImage *)image {
    NSString *directory = [self imagesDirectory];
    if (directory == nil) return nil;

    NSString *base = [NSString stringWithFormat:@"img-%u-%u",
                      (unsigned)time(NULL), (unsigned)arc4random()];
    NSString *fullPath = [directory stringByAppendingPathComponent:
                          [base stringByAppendingString:@".jpg"]];
    NSData *fullData = UIImageJPEGRepresentation(image, 0.80f);
    if (fullData == nil || ![fullData writeToFile:fullPath atomically:YES]) {
        return nil;
    }

    UIImage *thumb = [self resizedImage:image maxDimension:320.0f];
    NSData *thumbData = thumb ? UIImageJPEGRepresentation(thumb, 0.75f) : nil;
    NSString *thumbPath = fullPath;
    if (thumbData != nil) {
        NSString *candidate = [directory stringByAppendingPathComponent:
                               [base stringByAppendingString:@"-thumb.jpg"]];
        if ([thumbData writeToFile:candidate atomically:YES]) {
            thumbPath = candidate;
        }
    }

    return [NSDictionary dictionaryWithObjectsAndKeys:
            fullPath, @"full", thumbPath, @"thumb", nil];
}

- (UIImage *)imageForPath:(NSString *)path maxDimension:(CGFloat)maxDimension {
    if ([path length] == 0) return nil;
    UIImage *image = [_imageCache objectForKey:path];
    if (image != nil) return image;

    image = [UIImage imageWithContentsOfFile:path];
    if (image == nil) return nil;

    if (maxDimension > 0.0f &&
        (image.size.width > maxDimension || image.size.height > maxDimension)) {
        image = [self resizedImage:image maxDimension:maxDimension];
    }
    if (image != nil) {
        if ([_imageCache count] >= 16) [_imageCache removeAllObjects];
        [_imageCache setObject:image forKey:path];
    }
    return image;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [_imageCache removeAllObjects];
}

#pragma mark - MessageCellDelegate

- (void)messageCell:(MessageCell *)cell didTapImageWithPath:(NSString *)path {
    if ([path length] == 0) return;
    _savedContentOffset = _table.contentOffset;
    _restoreContentOffset = YES;
    [_input resignFirstResponder];

    ImageViewController *viewer = [[ImageViewController alloc] initWithImagePath:path];
    viewer.wantsFullScreenLayout = YES;

    UIViewController *presenter = self;
    if ([[[UIDevice currentDevice] model] rangeOfString:@"iPad"].location != NSNotFound) {
        UIViewController *root =
            [[[UIApplication sharedApplication] keyWindow] rootViewController];
        if (root != nil) presenter = root;
    }
    [presenter presentModalViewController:viewer animated:YES];
    [viewer release];
}

- (void)sessionsDidChange {
    [self loadCurrentSession];
}

- (void)loadCurrentSession {
    if (_streaming) {
        _streaming = NO;
        [_client cancel];
        [_client release];
        _client = nil;
        [_updateTimer invalidate];
        _updateTimer = nil;
        [_sendButton setTitle:NSLocalizedString(@"Send", nil) forState:UIControlStateNormal];
    }

    [_messages release];
    [_session release];
    _session = [[[SessionStore shared] currentSession] retain];
    _messages = [[_session objectForKey:@"messages"] retain];
    _restoreContentOffset = NO;
    [self updateNavigationTitle];
    [_table reloadData];
    [self scrollToBottom];
}

- (NSString *)textForRow:(NSInteger)row {
    NSDictionary *message = [_messages objectAtIndex:row];
    NSString *text = [message objectForKey:@"text"];
    if ([text length] > 0) return text;
    if ([[message objectForKey:@"images"] count] > 0) return @"";
    return @"…";
}

- (void)scrollToBottom {
    NSInteger count = (NSInteger)[_messages count];
    if (count == 0) return;
    NSInteger rows = (NSInteger)[_table numberOfRowsInSection:0];
    if (rows <= 0) return;
    if (count > rows) count = rows;
    [_table scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:count - 1 inSection:0]
                  atScrollPosition:UITableViewScrollPositionBottom
                          animated:NO];
}

- (void)updateSessionTitle:(NSString *)text hasImages:(BOOL)hasImages {
    if ([[_session objectForKey:@"title"] length] > 0) return;
    NSString *title = text;
    if ([title length] == 0 && hasImages) title = NSLocalizedString(@"Image", nil);
    if ([title length] == 0) return;
    if ([title length] > 16) title = [[title substringToIndex:16] stringByAppendingString:@"…"];
    [_session setObject:title forKey:@"title"];
    [self updateNavigationTitle];
}

- (void)updateNavigationTitle {
    NSString *title = [_session objectForKey:@"title"];
    if ([title length] == 0) {
        title = NSLocalizedString(@"New Session", nil);
    }
    self.title = title;
}

- (void)sessionsChanged {
    [self updateNavigationTitle];
}

- (void)send {
    if (_streaming) {
        [_client cancel];
        return;
    }

    NSString *text = [_input.text stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL hasImages = [_pendingImages count] > 0;
    if ([text length] == 0 && !hasImages) return;

    NSString *key = [[NSUserDefaults standardUserDefaults] stringForKey:@"api_key"];
    if ([key length] == 0) {
        [self openSettings];
        return;
    }

    NSString *model = [[NSUserDefaults standardUserDefaults] stringForKey:@"model"];
    if ([model length] == 0) model = @"deepseek-flash";

    NSMutableArray *imagePaths = [NSMutableArray array];
    NSMutableArray *thumbPaths = [NSMutableArray array];
    UIImage *pendingImage;
    for (pendingImage in _pendingImages) {
        NSDictionary *saved = [self savePendingImage:pendingImage];
        if (saved != nil) {
            [imagePaths addObject:[saved objectForKey:@"full"]];
            [thumbPaths addObject:[saved objectForKey:@"thumb"]];
        }
    }
    if ([text length] == 0 && [imagePaths count] == 0) return;

    NSMutableDictionary *userMessage = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                        @"user", @"role", text, @"text", nil];
    if ([imagePaths count] > 0) {
        [userMessage setObject:imagePaths forKey:@"images"];
        if ([thumbPaths count] == [imagePaths count]) {
            [userMessage setObject:thumbPaths forKey:@"image_thumbs"];
        }
    }
    [_messages addObject:userMessage];
    [_messages addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                          @"assistant", @"role", [NSMutableString string], @"text", nil]];
    [self updateSessionTitle:text hasImages:([imagePaths count] > 0)];
    [[SessionStore shared] save];

    _input.text = @"";
    [self clearPendingImages];
    /* Reload before scrolling: scrollToBottom: would otherwise ask the table
       for a row that the data source has but the table has not seen yet. */
    [_table reloadData];
    [self updateInputBarHeightAnimated:NO];

    _streaming = YES;
    [_sendButton setTitle:NSLocalizedString(@"Stop", nil) forState:UIControlStateNormal];

    NSArray *toSend = [_messages subarrayWithRange:NSMakeRange(0, [_messages count] - 1)];
    _client = [[DSClient alloc] init];
    _client.delegate = self;
    [_client sendMessages:toSend model:model apiKey:key];
}

- (void)scheduleUpdate {
    if (_updateTimer) return;
    _updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.12
                                                    target:self
                                                  selector:@selector(flushUpdate:)
                                                  userInfo:nil
                                                   repeats:NO];
}

- (void)flushUpdate:(NSTimer *)timer {
    _updateTimer = nil;

    NSInteger count = (NSInteger)[_messages count];
    NSInteger rows = (NSInteger)[_table numberOfRowsInSection:0];
    if (count <= 0) return;

    if (count != rows) {
        [_table reloadData];
        [self scrollToBottom];
        return;
    }

    CGFloat oldMaxY = _table.contentSize.height - _table.bounds.size.height;
    if (oldMaxY < 0.0f) oldMaxY = 0.0f;
    BOOL followBottom = (_table.contentOffset.y >= oldMaxY - 40.0f);

    NSIndexPath *last = [NSIndexPath indexPathForRow:count - 1 inSection:0];
    [_table reloadRowsAtIndexPaths:[NSArray arrayWithObject:last]
                  withRowAnimation:UITableViewRowAnimationNone];

    if (followBottom) {
        CGFloat maxY = _table.contentSize.height - _table.bounds.size.height;
        if (maxY < 0.0f) maxY = 0.0f;
        [_table setContentOffset:CGPointMake(0.0f, maxY) animated:NO];
    }
}

- (void)finishStreaming {
    if (!_streaming) return;
    _streaming = NO;
    [_sendButton setTitle:NSLocalizedString(@"Send", nil) forState:UIControlStateNormal];
    [_updateTimer invalidate];
    _updateTimer = nil;
    [_table reloadData];
    [self scrollToBottom];
    [[SessionStore shared] save];
    [_client release];
    _client = nil;
}

#pragma mark - DSClientDelegate

- (void)dsClientDidReceiveDelta:(NSString *)delta {
    if (!_streaming) return;
    NSMutableDictionary *message = [_messages lastObject];
    NSMutableString *text = [message objectForKey:@"text"];
    [text appendString:delta];
    [self scheduleUpdate];
}

- (void)dsClientDidFinish {
    [self finishStreaming];
}

- (void)dsClientDidFail:(NSString *)message {
    if (!_streaming) return;
    NSMutableDictionary *last = [_messages lastObject];
    NSMutableString *text = [last objectForKey:@"text"];
    if ([text length] == 0) [text setString:message];
    else [text appendFormat:@"\n\n[%@]", message];
    [self finishStreaming];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)[_messages count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"MessageCell";
    MessageCell *cell = (MessageCell *)[tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[[MessageCell alloc] initWithStyle:UITableViewCellStyleDefault
                                   reuseIdentifier:identifier] autorelease];
    }

    NSDictionary *message = [_messages objectAtIndex:indexPath.row];
    BOOL outgoing = [[message objectForKey:@"role"] isEqualToString:@"user"];

    NSArray *imagePaths = [message objectForKey:@"images"];
    NSArray *thumbPaths = [message objectForKey:@"image_thumbs"];
    NSMutableArray *images = nil;
    NSMutableArray *displayPaths = nil;
    if ([imagePaths count] > 0) {
        images = [NSMutableArray array];
        displayPaths = [NSMutableArray array];
        NSUInteger i;
        for (i = 0; i < [imagePaths count]; i++) {
            NSString *fullPath = [imagePaths objectAtIndex:i];
            NSString *thumbPath = (i < [thumbPaths count])
                ? [thumbPaths objectAtIndex:i] : fullPath;
            UIImage *image = [self imageForPath:thumbPath maxDimension:320.0f];
            if (image == nil) {
                image = [self imageForPath:fullPath maxDimension:320.0f];
            }
            if (image != nil) {
                [images addObject:image];
                [displayPaths addObject:fullPath];
            }
        }
    }

    cell.delegate = self;
    [cell setText:[self textForRow:indexPath.row] images:images
        imagePaths:displayPaths outgoing:outgoing];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *imagePaths = [[_messages objectAtIndex:indexPath.row] objectForKey:@"images"];
    return [MessageCell heightForText:[self textForRow:indexPath.row]
                           imageCount:[imagePaths count]];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    [_input resignFirstResponder];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [_input resignFirstResponder];
}

- (void)dismissKeyboard {
    [_input resignFirstResponder];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    if ([[[UIDevice currentDevice] model] rangeOfString:@"iPad"].location != NSNotFound) {
        return YES;
    }
    return interfaceOrientation == UIInterfaceOrientationPortrait;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    [self layoutViews];
    [_table reloadData];
    [self scrollToBottom];
}

#pragma mark - UITextViewDelegate

- (void)textViewDidBeginEditing:(UITextView *)textView {
    if ([textView.text length] == 0) {
        textView.contentOffset = CGPointZero;
        textView.selectedRange = NSMakeRange(0, 0);
    }
}

- (void)textViewDidChange:(UITextView *)textView {
    [self updateInputBarHeightAnimated:NO];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_updateTimer invalidate];
    [_client release];
    [_session release];
    [_messages release];
    [_table release];
    [_inputBar release];
    [_inputFieldBackground release];
    [_input release];
    [_inputPlaceholder release];
    [_thumbnailContainer release];
    [_pendingImages release];
    [_thumbnailViews release];
    [_imageCache release];
    if (_imagePickerPopover != nil) {
        UIPopoverController *popover = (UIPopoverController *)_imagePickerPopover;
        popover.delegate = nil;
        [popover dismissPopoverAnimated:NO];
        [_imagePickerPopover release];
    }
    if (_settingsPopover != nil) {
        UIPopoverController *popover = (UIPopoverController *)_settingsPopover;
        popover.delegate = nil;
        [popover dismissPopoverAnimated:NO];
        [_settingsPopover release];
    }
    [super dealloc];
}

@end
