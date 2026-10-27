#import "RenameViewController.h"
#include <math.h>

@interface RenameFieldCell : UITableViewCell
@end

@implementation RenameFieldCell

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect bounds = self.contentView.bounds;
    CGFloat labelWidth = 120.0f;
    CGFloat rightMargin = 10.0f;
    CGFloat fieldWidth = bounds.size.width - labelWidth - rightMargin;
    if (fieldWidth < 40.0f) fieldWidth = 40.0f;

    for (UIView *view in self.contentView.subviews) {
        if ([view isKindOfClass:[UITextField class]]) {
            UITextField *field = (UITextField *)view;
            UIFont *font = field.font ? field.font : [UIFont systemFontOfSize:17.0f];
            CGFloat fieldHeight = ceilf(font.ascender - font.descender) + 4.0f;
            if (fieldHeight < 24.0f) fieldHeight = 24.0f;
            CGFloat fieldY = floorf((bounds.size.height - fieldHeight) / 2.0f);
            if (fieldY < 2.0f) fieldY = 2.0f;
            field.frame = CGRectMake(labelWidth, fieldY, fieldWidth, fieldHeight);
        }
    }
}

@end

@implementation RenameViewController

@synthesize sessionIndex = _sessionIndex;
@synthesize delegate = _delegate;

- (id)initWithTitle:(NSString *)title {
    if ((self = [super init])) {
        _originalTitle = [title copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"Rename Session", nil);

    self.navigationItem.leftBarButtonItem =
        [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel", nil)
                                          style:UIBarButtonItemStyleBordered
                                         target:self
                                         action:@selector(cancel)] autorelease];
    self.navigationItem.rightBarButtonItem =
        [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Save", nil)
                                          style:UIBarButtonItemStyleDone
                                         target:self
                                         action:@selector(save)] autorelease];

    UITableView *table = [[UITableView alloc] initWithFrame:self.view.bounds
                                                      style:UITableViewStyleGrouped];
    table.dataSource = self;
    table.delegate = self;
    table.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                             UIViewAutoresizingFlexibleHeight;
    self.view = table;
    [table release];

    _textField = [[UITextField alloc] initWithFrame:CGRectZero];
    _textField.borderStyle = UITextBorderStyleNone;
    _textField.textAlignment = UITextAlignmentRight;
    _textField.textColor = [UIColor colorWithRed:0.20f green:0.31f blue:0.52f alpha:1.0f];
    _textField.font = [UIFont systemFontOfSize:17.0f];
    _textField.text = _originalTitle;
    _textField.placeholder = NSLocalizedString(@"Session name", nil);
    _textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _textField.returnKeyType = UIReturnKeyDone;
    _textField.autocorrectionType = UITextAutocorrectionTypeNo;
    _textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _textField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _textField.delegate = self;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"RenameSessionCell";
    RenameFieldCell *cell = (RenameFieldCell *)[tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[[RenameFieldCell alloc] initWithStyle:UITableViewCellStyleDefault
                                       reuseIdentifier:identifier] autorelease];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.font = [UIFont boldSystemFontOfSize:17.0f];
        cell.textLabel.text = NSLocalizedString(@"Session name", nil);
    }

    if (_textField.superview != cell.contentView) {
        [_textField removeFromSuperview];
        [cell.contentView addSubview:_textField];
    }
    [cell setNeedsLayout];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0f;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [_textField becomeFirstResponder];
}

- (void)cancel {
    if (_delegate != nil &&
        [_delegate respondsToSelector:@selector(renameViewControllerDidCancel:)]) {
        [_delegate renameViewControllerDidCancel:self];
    } else {
        [self dismissModalViewControllerAnimated:YES];
    }
}

- (void)save {
    NSString *title = [_textField.text stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([title length] == 0) {
        title = NSLocalizedString(@"New Session", nil);
    }

    if (_delegate != nil &&
        [_delegate respondsToSelector:@selector(renameViewController:didFinishWithTitle:)]) {
        [_delegate renameViewController:self didFinishWithTitle:title];
    } else {
        [self dismissModalViewControllerAnimated:YES];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self save];
    return NO;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    if ([[[UIDevice currentDevice] model] rangeOfString:@"iPad"].location != NSNotFound) {
        return YES;
    }
    return interfaceOrientation == UIInterfaceOrientationPortrait;
}

- (void)dealloc {
    [_originalTitle release];
    [_textField release];
    [super dealloc];
}

@end
