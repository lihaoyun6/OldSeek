#import <UIKit/UIKit.h>

@class MessageCell;

@protocol MessageCellDelegate <NSObject>
- (void)messageCell:(MessageCell *)cell didTapImageWithPath:(NSString *)path;
@end

@interface MessageCell : UITableViewCell {
    UIView *_bubble;
    UITextView *_textView;
    NSArray *_images;
    NSArray *_imagePaths;
    NSMutableArray *_imageViews;
    NSString *_text;
    BOOL _outgoing;
    id<MessageCellDelegate> _delegate;
    CGSize _cachedTextSize;
    CGFloat _cachedTextWidth;
}

@property (nonatomic, assign) id<MessageCellDelegate> delegate;

- (void)setText:(NSString *)text outgoing:(BOOL)outgoing;
- (void)setText:(NSString *)text images:(NSArray *)images outgoing:(BOOL)outgoing;
- (void)setText:(NSString *)text images:(NSArray *)images imagePaths:(NSArray *)imagePaths outgoing:(BOOL)outgoing;

+ (CGFloat)heightForText:(NSString *)text;
+ (CGFloat)heightForText:(NSString *)text imageCount:(NSInteger)imageCount;
+ (void)setMaxTextWidth:(CGFloat)width;

@end
