#import "SettingsViewController.h"
#import "CenteredTextField.h"
#include <math.h>

@interface SettingsFieldCell : UITableViewCell
@end

@implementation SettingsFieldCell

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect bounds = self.contentView.bounds;
    CGFloat labelWidth = 110.0f;
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

@implementation SettingsViewController

@synthesize delegate = _delegate;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"Settings", nil);

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
    table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:table];
    [table release];
}

- (UITextField *)fieldInCell:(UITableViewCell *)cell {
    UITextField *field = [[[CenteredTextField alloc] initWithFrame:CGRectZero] autorelease];
    field.borderStyle = UITextBorderStyleNone;
    field.textAlignment = UITextAlignmentRight;
    field.textColor = [UIColor colorWithRed:0.20f green:0.31f blue:0.52f alpha:1.0f];
    field.font = [UIFont systemFontOfSize:17.0f];
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    field.delegate = self;
    [cell.contentView addSubview:field];
    return field;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SettingsFieldCell *cell = [[[SettingsFieldCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                       reuseIdentifier:nil] autorelease];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:17.0f];

    if (indexPath.section == 0) {
        cell.textLabel.text = @"API Key";
        _keyField = [[self fieldInCell:cell] retain];
        _keyField.placeholder = @"sk-...";
        _keyField.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"api_key"];
        _keyField.returnKeyType = UIReturnKeyNext;
    } else {
        cell.textLabel.text = NSLocalizedString(@"Model", nil);
        _modelField = [[self fieldInCell:cell] retain];
        _modelField.placeholder = @"deepseek-flash";
        NSString *model = [[NSUserDefaults standardUserDefaults] stringForKey:@"model"];
        _modelField.text = [model length] > 0 ? model : @"deepseek-flash";
        _modelField.returnKeyType = UIReturnKeyDone;
    }
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1) {
        NSString *footer = NSLocalizedString(@"The API key is stored only in this device's preferences", nil);
        NSString *version = [[[NSBundle mainBundle] infoDictionary]
                             objectForKey:@"CFBundleShortVersionString"];
        if ([version length] == 0) version = @"1.0.0";
        return [NSString stringWithFormat:@"%@\n\n\nOldSeek v%@", footer, version];
    }
    return nil;
}

- (void)finish {
    if (_delegate != nil &&
        [_delegate respondsToSelector:@selector(settingsViewControllerDidFinish)]) {
        [_delegate settingsViewControllerDidFinish];
    } else {
        [self dismissModalViewControllerAnimated:YES];
    }
}

- (void)cancel {
    [self finish];
}

- (void)save {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSString *key = [_keyField.text stringByTrimmingCharactersInSet:
                     [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *model = [_modelField.text stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([model length] == 0) model = @"deepseek-flash";

    [defs setObject:key forKey:@"api_key"];
    [defs setObject:model forKey:@"model"];
    [defs synchronize];

    [self finish];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == _keyField) [_modelField becomeFirstResponder];
    else [self save];
    return NO;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    if ([[[UIDevice currentDevice] model] rangeOfString:@"iPad"].location != NSNotFound) {
        return YES;
    }
    return interfaceOrientation == UIInterfaceOrientationPortrait;
}

- (void)dealloc {
    [_keyField release];
    [_modelField release];
    [super dealloc];
}

@end
