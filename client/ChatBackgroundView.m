#import "ChatBackgroundView.h"

@implementation ChatBackgroundView

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.opaque = YES;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                UIViewAutoresizingFlexibleHeight;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetRGBFillColor(ctx, 220.0f / 255.0f, 226.0f / 255.0f,
                             236.0f / 255.0f, 1.0f);
    CGContextFillRect(ctx, self.bounds);
}

@end
