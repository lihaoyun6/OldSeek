#import "ImageThumbnailView.h"
#import <QuartzCore/QuartzCore.h>

@interface DeleteBadgeButton : UIButton
@end

@implementation DeleteBadgeButton

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect r = CGRectInset(self.bounds, 1.0f, 1.0f);

    CGContextSetRGBFillColor(ctx, 1.0f, 1.0f, 1.0f, 1.0f);
    CGContextFillEllipseInRect(ctx, r);

    r = CGRectInset(r, 1.5f, 1.5f);
    CGContextSetRGBFillColor(ctx, 0.82f, 0.10f, 0.12f, 1.0f);
    CGContextFillEllipseInRect(ctx, r);

    CGFloat inset = 5.5f;
    CGContextSetRGBStrokeColor(ctx, 1.0f, 1.0f, 1.0f, 1.0f);
    CGContextSetLineWidth(ctx, 2.0f);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextMoveToPoint(ctx, r.origin.x + inset, CGRectGetMidY(r));
    CGContextAddLineToPoint(ctx, CGRectGetMaxX(r) - inset, CGRectGetMidY(r));
    CGContextStrokePath(ctx);
}

@end

@implementation ImageThumbnailView

- (id)initWithImage:(UIImage *)image size:(CGFloat)size {
    CGFloat width = size + 10.0f;
    CGFloat height = size + 8.0f;
    if ((self = [super initWithFrame:CGRectMake(0, 0, width, height)])) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;

        _imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 8.0f, size, size)];
        _imageView.image = image;
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        _imageView.backgroundColor = [UIColor whiteColor];
        _imageView.layer.cornerRadius = 7.0f;
        _imageView.layer.masksToBounds = YES;
        _imageView.layer.borderWidth = 1.0f;
        _imageView.layer.borderColor = [UIColor colorWithRed:0.46f green:0.51f blue:0.58f alpha:1.0f].CGColor;
        [self addSubview:_imageView];

        _deleteButton = [[DeleteBadgeButton alloc] initWithFrame:
                         CGRectMake(size - 12.0f, 0.0f, 22.0f, 22.0f)];
        _deleteButton.backgroundColor = [UIColor clearColor];
        _deleteButton.opaque = NO;
        [self addSubview:_deleteButton];
    }
    return self;
}

- (void)setDeleteTarget:(id)target action:(SEL)action {
    _deleteTarget = target;
    _deleteAction = action;
    [_deleteButton removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    [_deleteButton addTarget:self action:@selector(deleteTapped:)
            forControlEvents:UIControlEventTouchUpInside];
}

- (void)deleteTapped:(id)sender {
    if (_deleteTarget != nil && _deleteAction != NULL) {
        [_deleteTarget performSelector:_deleteAction withObject:self];
    }
}

- (void)dealloc {
    [_imageView release];
    [_deleteButton release];
    [super dealloc];
}

@end
