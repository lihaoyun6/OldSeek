#import <UIKit/UIKit.h>
#import "DSClient.h"
#import "SessionsViewController.h"
#import "SettingsViewController.h"
#import "MessageCell.h"

@class ChatViewController;

@protocol ChatViewControllerSplitDelegate <NSObject>
- (void)chatViewControllerDidTapSessions;
@end

@interface ChatViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UITextViewDelegate, DSClientDelegate, SessionsViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, MessageCellDelegate, SettingsViewControllerDelegate> {
    UITableView *_table;
    UIView *_inputBar;
    UIView *_inputFieldBackground;
    UITextView *_input;
    UILabel *_inputPlaceholder;
    UIButton *_sendButton;
    UIButton *_cameraButton;
    UIView *_thumbnailContainer;
    NSMutableArray *_pendingImages;
    NSMutableArray *_thumbnailViews;
    NSMutableDictionary *_imageCache;
    NSMutableDictionary *_session;
    NSMutableArray *_messages;
    DSClient *_client;
    BOOL _streaming;
    NSTimer *_updateTimer;
    CGFloat _keyboardHeight;
    BOOL _openedSettings;
    BOOL _scrollToBottomOnAppear;
    BOOL _restoreContentOffset;
    CGPoint _savedContentOffset;
    BOOL _splitMode;
    id<ChatViewControllerSplitDelegate> _splitDelegate;
    id _imagePickerPopover;
    id _settingsPopover;
}

@property (nonatomic, assign) id<ChatViewControllerSplitDelegate> splitDelegate;

- (id)initWithSplitMode:(BOOL)splitMode;
- (void)relayout;
- (void)updateNavigationTitle;

@end
