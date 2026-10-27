#import "MessageCell.h"
#import "BubbleView.h"
#import <QuartzCore/QuartzCore.h>
#include <math.h>

static CGFloat gMaxTextWidth = 240.0f;
static const CGFloat kPadX         = 12.0f;
static const CGFloat kPadY         = 8.0f;
static const CGFloat kTextTop      = 11.0f;
static const CGFloat kTailWidth    = 8.0f;
static const CGFloat kTailHeight   = 8.0f;
static const CGFloat kSideMargin   = 10.0f;
static const CGFloat kRowMargin    = 4.0f;
static const CGFloat kTextViewInset = 8.0f;
/* Give the text view a little more room than the measured text width. WebKit's
   line breaking can need a few pixels more than UIKit's sizeWithFont:, and
   without this a one-line measurement can render as two lines and get cut off. */
static const CGFloat kTextViewSlack = 10.0f;
static const CGFloat kImageGap      = 4.0f;
static const CGFloat kImageTextGap  = 6.0f;

/* UIImageView that reports taps back to the cell so the full-size image can be
   opened. iOS 3.1.3 has no gesture recognizers, so this is done with touches. */
@interface MessageImageView : UIImageView {
    id _tapTarget;
    SEL _tapAction;
    NSInteger _imageIndex;
}
@property (nonatomic) NSInteger imageIndex;
- (void)setTapTarget:(id)target action:(SEL)action;
@end

@implementation MessageImageView

@synthesize imageIndex = _imageIndex;

- (void)setTapTarget:(id)target action:(SEL)action {
    _tapTarget = target;
    _tapAction = action;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    if (_tapTarget != nil && _tapAction != NULL) {
        [_tapTarget performSelector:_tapAction withObject:self];
    }
}

@end

/* UITextView is used instead of UILabel so iOS 3's own selection UI (magnifier,
   draggable handles, Copy menu) works on message text. */
@interface MessageTextView : UITextView {
    id _tapTarget;
    SEL _tapAction;
}
- (void)setTapTarget:(id)target action:(SEL)action;
@end

@implementation MessageTextView

- (void)setTapTarget:(id)target action:(SEL)action {
    _tapTarget = target;
    _tapAction = action;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    if (_tapTarget != nil && _tapAction != NULL) {
        [_tapTarget performSelector:_tapAction];
    }
}

@end

@implementation MessageCell

@synthesize delegate = _delegate;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.contentView.opaque = NO;
        self.contentView.backgroundColor = [UIColor clearColor];

        _bubble = [[BubbleView alloc] init];
        [self.contentView addSubview:_bubble];

        _imageViews = [[NSMutableArray alloc] init];
        int i;
        for (i = 0; i < 4; i++) {
            MessageImageView *imageView = [[MessageImageView alloc] init];
            imageView.contentMode = UIViewContentModeScaleAspectFill;
            imageView.clipsToBounds = YES;
            imageView.userInteractionEnabled = YES;
            imageView.backgroundColor = [UIColor whiteColor];
            imageView.layer.cornerRadius = 6.0f;
            imageView.layer.masksToBounds = YES;
            imageView.layer.borderWidth = 1.0f;
            imageView.layer.borderColor = [UIColor colorWithRed:0.46f green:0.51f blue:0.58f alpha:1.0f].CGColor;
            imageView.hidden = YES;
            [imageView setTapTarget:self action:@selector(handleImageTap:)];
            [self.contentView addSubview:imageView];
            [_imageViews addObject:imageView];
            [imageView release];
        }

        _textView = [[MessageTextView alloc] init];
        _textView.editable = NO;
        _textView.scrollEnabled = NO;
        _textView.opaque = NO;
        _textView.backgroundColor = [UIColor clearColor];
        _textView.textColor = [UIColor blackColor];
        _textView.font = [UIFont systemFontOfSize:15.0f];
        _textView.dataDetectorTypes = UIDataDetectorTypeNone;
        [(MessageTextView *)_textView setTapTarget:self action:@selector(handleTap)];
        [self.contentView addSubview:_textView];
    }
    return self;
}

- (void)handleTap {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MessageCellTapped"
                                                        object:self];
}

- (void)handleImageTap:(MessageImageView *)imageView {
    NSInteger index = imageView.imageIndex;
    NSString *path = nil;
    if (index >= 0 && index < (NSInteger)[_imagePaths count]) {
        path = [_imagePaths objectAtIndex:index];
    }
    if (path != nil &&
        [_delegate respondsToSelector:@selector(messageCell:didTapImageWithPath:)]) {
        [_delegate messageCell:self didTapImageWithPath:path];
    }
}

- (void)setText:(NSString *)text outgoing:(BOOL)outgoing {
    [self setText:text images:nil imagePaths:nil outgoing:outgoing];
}

- (void)setText:(NSString *)text images:(NSArray *)images outgoing:(BOOL)outgoing {
    [self setText:text images:images imagePaths:nil outgoing:outgoing];
}

- (void)setText:(NSString *)text images:(NSArray *)images
       imagePaths:(NSArray *)imagePaths outgoing:(BOOL)outgoing {
    if (_text != text) {
        [_text release];
        _text = [text copy];
    }
    [_images release];
    _images = [images copy];
    [_imagePaths release];
    _imagePaths = [imagePaths copy];

    _outgoing = outgoing;
    [(BubbleView *)_bubble setOutgoing:outgoing];
    _textView.text = _text;

    if ([_text length] > 0) {
        _cachedTextSize = [MessageCell textSizeForText:_text];
        _cachedTextWidth = [MessageCell textWidthForText:_text];
    } else {
        _cachedTextSize = CGSizeZero;
        _cachedTextWidth = 0.0f;
    }

    NSUInteger count = [_images count];
    if (count > [_imageViews count]) count = [_imageViews count];
    NSUInteger i;
    for (i = 0; i < [_imageViews count]; i++) {
        MessageImageView *imageView = [_imageViews objectAtIndex:i];
        if (i < count) {
            imageView.image = [_images objectAtIndex:i];
            imageView.imageIndex = (NSInteger)i;
            imageView.hidden = NO;
        } else {
            imageView.image = nil;
            imageView.hidden = YES;
        }
    }
    [self setNeedsLayout];
}

+ (void)setMaxTextWidth:(CGFloat)width {
    if (width < 200.0f) width = 200.0f;
    if (width > 560.0f) width = 560.0f;
    gMaxTextWidth = width;
}

+ (CGFloat)thumbnailSizeForCount:(NSInteger)imageCount {
    if (imageCount <= 0) return 0.0f;
    BOOL wide = (gMaxTextWidth > 250.0f);
    if (imageCount == 1) return wide ? 220.0f : 150.0f;
    if (imageCount == 2) return wide ? 160.0f : 110.0f;
    if (imageCount == 3) return wide ? 110.0f : 80.0f;
    return wide ? 82.0f : 62.0f;
}

+ (CGFloat)textWidthForText:(NSString *)text {
    UIFont *font = [UIFont systemFontOfSize:15.0f];
    CGSize oneLine = [text sizeWithFont:font];

    CGFloat width = ceilf(oneLine.width);
    if (width > gMaxTextWidth) width = gMaxTextWidth;
    if (width < 20.0f) width = 20.0f;
    return width;
}

+ (CGSize)textSizeForText:(NSString *)text {
    UIFont *font = [UIFont systemFontOfSize:15.0f];
    CGSize oneLine = [text sizeWithFont:font];
    CGFloat width = [self textWidthForText:text] + kTextViewSlack;

    CGSize wrapped = [text sizeWithFont:font
                      constrainedToSize:CGSizeMake(width, 10000.0f)
                          lineBreakMode:UILineBreakModeWordWrap];

    /* A long unbreakable token (URL, English word) or a long block of CJK can
       make word wrap report a single line even though the text view will break
       it. Measure again with character wrapping so the bubble is tall enough. */
    if (oneLine.width > width &&
        wrapped.height <= ceilf(oneLine.height) + 1.0f) {
        wrapped = [text sizeWithFont:font
                   constrainedToSize:CGSizeMake(width, 10000.0f)
                       lineBreakMode:UILineBreakModeCharacterWrap];
    }
    return wrapped;
}

+ (CGFloat)heightForText:(NSString *)text {
    return [self heightForText:text imageCount:0];
}

+ (CGFloat)heightForText:(NSString *)text imageCount:(NSInteger)imageCount {
    if (imageCount < 0) imageCount = 0;
    BOOL hasText = [text length] > 0;
    CGFloat imageRowHeight = [self thumbnailSizeForCount:imageCount];

    CGFloat contentHeight = 0.0f;
    if (imageCount > 0) contentHeight += imageRowHeight;
    if (hasText) {
        if (imageCount > 0) contentHeight += kImageTextGap;
        contentHeight += [self textSizeForText:text].height;
    }

    return kPadY + contentHeight + kPadY + kTailHeight + 2.0f * kRowMargin;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    NSInteger imageCount = (NSInteger)[_images count];
    if (imageCount > 4) imageCount = 4;
    BOOL hasText = [_text length] > 0;

    CGSize wrapped = hasText ? _cachedTextSize : CGSizeZero;
    CGFloat textWidth = hasText ? _cachedTextWidth : 0.0f;
    CGFloat imageSize = [MessageCell thumbnailSizeForCount:imageCount];
    CGFloat imagesWidth = imageCount > 0
        ? imageCount * imageSize + (imageCount - 1) * kImageGap
        : 0.0f;

    CGFloat contentWidth = MAX(textWidth, imagesWidth);
    CGFloat bodyWidth = contentWidth + 2.0f * kPadX;
    CGFloat bubbleWidth = bodyWidth + kTailWidth;

    CGFloat contentHeight = 0.0f;
    if (imageCount > 0) contentHeight += imageSize;
    if (hasText) {
        if (imageCount > 0) contentHeight += kImageTextGap;
        contentHeight += wrapped.height;
    }
    CGFloat bubbleHeight = kPadY + contentHeight + kPadY + kTailHeight;

    CGFloat x = _outgoing
        ? (self.bounds.size.width - kSideMargin - bubbleWidth)
        : kSideMargin;
    _bubble.frame = CGRectMake(x, kRowMargin, bubbleWidth, bubbleHeight);

    CGFloat bodyX = _outgoing ? 0.0f : kTailWidth;

    NSUInteger i;
    for (i = 0; i < [_imageViews count]; i++) {
        UIImageView *imageView = [_imageViews objectAtIndex:i];
        if ((NSInteger)i < imageCount) {
            imageView.frame = CGRectMake(x + bodyX + kPadX + i * (imageSize + kImageGap),
                                         kRowMargin + kPadY,
                                         imageSize, imageSize);
            imageView.hidden = NO;
        } else {
            imageView.hidden = YES;
        }
    }

    _textView.hidden = !hasText;
    if (hasText) {
        CGFloat textTop = imageCount > 0
            ? (kPadY + imageSize + kImageTextGap)
            : kTextTop;
        /* UITextView has a hard-coded 8px inner inset; expand its frame by that
           amount so the glyphs land exactly on the intended text rectangle, plus
           a little slack so WebKit does not wrap earlier than sizeWithFont: did. */
        _textView.frame = CGRectMake(x + bodyX + kPadX - kTextViewInset,
                                     kRowMargin + textTop - kTextViewInset,
                                     textWidth + 2.0f * kTextViewInset + kTextViewSlack,
                                     wrapped.height + 2.0f * kTextViewInset + 1.0f);
    }
}

- (void)dealloc {
    [_text release];
    [_images release];
    [_imagePaths release];
    [_imageViews release];
    [_textView release];
    [_bubble release];
    [super dealloc];
}

@end
