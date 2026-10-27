#import "ChatInputBarView.h"

@implementation ChatInputBarView

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.opaque = YES;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGFloat colors[8] = {
        248.0f / 255.0f, 248.0f / 255.0f, 248.0f / 255.0f, 1.0f,
        197.0f / 255.0f, 199.0f / 255.0f, 203.0f / 255.0f, 1.0f
    };
    CGFloat locations[2] = { 0.0f, 1.0f };
    CGGradientRef gradient = CGGradientCreateWithColorComponents(space, colors,
                                                                locations, 2);
    CGContextDrawLinearGradient(ctx, gradient,
                                CGPointMake(0.0f, 0.0f),
                                CGPointMake(0.0f, self.bounds.size.height), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(space);

    CGContextSetRGBStrokeColor(ctx, 142.0f / 255.0f, 143.0f / 255.0f,
                               147.0f / 255.0f, 1.0f);
    CGContextSetLineWidth(ctx, 1.0f);
    CGContextMoveToPoint(ctx, 0.0f, 0.5f);
    CGContextAddLineToPoint(ctx, self.bounds.size.width, 0.5f);
    CGContextStrokePath(ctx);
}

@end
