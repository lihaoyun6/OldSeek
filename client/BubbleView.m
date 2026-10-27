#import "BubbleView.h"

@implementation BubbleView

/* The balloon artwork comes from iOS 3's own ChatKit.framework. Both source
   images are 43x32 with the tail on the right, so the incoming one is mirrored
   once and cached. */
static UIImage *MirrorImage(UIImage *image) {
    CGImageRef cg = image.CGImage;
    size_t width = CGImageGetWidth(cg);
    size_t height = CGImageGetHeight(cg);
    if (width == 0 || height == 0) return image;

    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, width, height, 8, width * 4,
                                             space, kCGImageAlphaPremultipliedLast);
    if (ctx == NULL) {
        CGColorSpaceRelease(space);
        return image;
    }

    CGContextTranslateCTM(ctx, (CGFloat)width, 0.0f);
    CGContextScaleCTM(ctx, -1.0f, 1.0f);
    CGContextDrawImage(ctx, CGRectMake(0, 0, width, height), cg);

    CGImageRef mirrored = CGBitmapContextCreateImage(ctx);
    UIImage *result = mirrored ? [UIImage imageWithCGImage:mirrored] : image;
    if (mirrored) CGImageRelease(mirrored);
    CGContextRelease(ctx);
    CGColorSpaceRelease(space);
    return result;
}

+ (UIImage *)imageForOutgoing:(BOOL)outgoing {
    static UIImage *outgoingImage = nil;
    static UIImage *incomingImage = nil;

    if (outgoing) {
        if (outgoingImage == nil) {
            UIImage *base = [UIImage imageNamed:@"Balloon_1.png"];
            outgoingImage = [[base stretchableImageWithLeftCapWidth:14
                                                       topCapHeight:15] retain];
        }
        return outgoingImage;
    }

    if (incomingImage == nil) {
        UIImage *base = [UIImage imageNamed:@"Balloon_2.png"];
        UIImage *mirrored = MirrorImage(base);
        /* The tail now sits on the left, so protect the left 28px instead of
           the right one. */
        incomingImage = [[mirrored stretchableImageWithLeftCapWidth:28
                                                        topCapHeight:15] retain];
    }
    return incomingImage;
}

- (id)init {
    if ((self = [super init])) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)setOutgoing:(BOOL)outgoing {
    if (_outgoing == outgoing) return;
    _outgoing = outgoing;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    UIImage *image = [BubbleView imageForOutgoing:_outgoing];
    if (image == nil) return;
    [image drawInRect:self.bounds];
}

@end
