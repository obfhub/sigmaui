#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

#pragma mark - Scene-safe key window (iOS 18 safe)

static UIWindow *FindKeyWindow(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive) continue;
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;

        UIWindowScene *ws = (UIWindowScene *)scene;
        for (UIWindow *w in ws.windows) {
            if (w.isKeyWindow) return w;
        }
        for (UIWindow *w in ws.windows) {
            if (!w.hidden && w.alpha > 0.0) return w;
        }
    }
    return nil;
}

#pragma mark - Passthrough container (never blocks app)

@interface CheatPassthroughContainer : UIView
@property (nonatomic, weak) UIView *logoView;
@property (nonatomic, weak) UIView *panelView;
@end

@implementation CheatPassthroughContainer

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.logoView && CGRectContainsPoint(self.logoView.frame, point)) return YES;
    if (self.panelView && !self.panelView.hidden &&
        CGRectContainsPoint(self.panelView.frame, point)) return YES;
    return NO;
}

@end

#pragma mark - Simple global state

static CheatPassthroughContainer *gContainer = nil;
static UIButton *gLogo = nil;
static UIView *gPanel = nil;
static BOOL gPanelVisible = NO;

static BOOL gGodMode = NO;
static BOOL gWallhack = NO;
static BOOL gAimbot = NO;
static float gSpeed = 1.0f;

#pragma mark - UI builders

static UISwitch *AddToggle(UIView *panel, NSString *name, CGFloat y, BOOL initial, SEL action, id target) {
    CGFloat W = panel.bounds.size.width;

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(12, y, 180, 24)];
    label.text = name;
    label.textColor = UIColor.whiteColor;
    label.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
    [panel addSubview:label];

    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectZero];
    sw.on = initial;
    sw.center = CGPointMake(W - 40, y + 12);
    [sw addTarget:target action:action forControlEvents:UIControlEventValueChanged];
    sw.onTintColor = [UIColor colorWithRed:0.8 green:0.1 blue:0.9 alpha:1.0];
    [panel addSubview:sw];

    return sw;
}

@interface CheatHandlers : NSObject
@end
@implementation CheatHandlers
- (void)toggleGod:(UISwitch *)sw { gGodMode = sw.isOn; }
- (void)toggleWall:(UISwitch *)sw { gWallhack = sw.isOn; }
- (void)toggleAim:(UISwitch *)sw  { gAimbot = sw.isOn; }
- (void)speedChanged:(UISlider *)sl { gSpeed = sl.value; }
@end

static CheatHandlers *gHandlers = nil;

static void TogglePanel(void);

static void HandleDrag(UIPanGestureRecognizer *pan) {
    CGPoint t = [pan translationInView:gContainer];
    gLogo.center = CGPointMake(gLogo.center.x + t.x, gLogo.center.y + t.y);
    [pan setTranslation:CGPointZero inView:gContainer];

    // keep panel attached to logo
    CGFloat W = gPanel.bounds.size.width;
    gPanel.center = CGPointMake(gLogo.center.x + W/2 + 10, gLogo.center.y);

    if (pan.state == UIGestureRecognizerStateEnded) {
        UIWindow *win = gContainer.window;
        if (!win) return;

        CGFloat left = 20 + gLogo.bounds.size.width/2;
        CGFloat right = win.bounds.size.width - left;
        CGFloat targetX = (gLogo.center.x < win.bounds.size.width/2) ? left : right;

        [UIView animateWithDuration:0.2 animations:^{
            gLogo.center = CGPointMake(targetX, gLogo.center.y);
            gPanel.center = CGPointMake(gLogo.center.x + W/2 + 10, gLogo.center.y);
        }];
    }
}

static void BuildUI(UIWindow *window) {
    if (gContainer) return; // already built

    gHandlers = [CheatHandlers new];

    // Fullscreen passthrough container
    gContainer = [[CheatPassthroughContainer alloc] initWithFrame:window.bounds];
    gContainer.backgroundColor = UIColor.clearColor;
    gContainer.userInteractionEnabled = YES;

    // Floating logo bubble
    CGFloat size = 58;
    gLogo = [UIButton buttonWithType:UIButtonTypeCustom];
    gLogo.frame = CGRectMake(30, 140, size, size);
    gLogo.layer.cornerRadius = size/2;
    gLogo.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.95];

    UIImageSymbolConfiguration *cfg =
        [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightBold];
    UIImage *icon = [UIImage systemImageNamed:@"bolt.fill" withConfiguration:cfg];

    if (icon) {
        [gLogo setImage:icon forState:UIControlStateNormal];
        gLogo.tintColor = [UIColor colorWithRed:0.8 green:0.1 blue:0.9 alpha:1.0];
    } else {
        [gLogo setTitle:@"⚡️" forState:UIControlStateNormal];
        [gLogo setTitleColor:[UIColor colorWithRed:0.8 green:0.1 blue:0.9 alpha:1.0] forState:UIControlStateNormal];
        gLogo.titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    }

    gLogo.layer.borderWidth = 2.0;
    gLogo.layer.borderColor = gLogo.tintColor.CGColor;

    [gLogo addTarget:(id)gHandlers action:@selector(dummy) forControlEvents:UIControlEventTouchUpInside];
    [gLogo addTarget:nil action:@selector(togglePanelProxy) forControlEvents:UIControlEventTouchUpInside];

    // Instead of selectors confusion, use addTarget with block-ish via category:
    [gLogo addTarget:gHandlers action:@selector(dummy) forControlEvents:UIControlEventTouchUpInside];

    // We'll hook toggle with UIControl event below using direct IMP.
    [gLogo addTarget:(id)gHandlers action:@selector(dummy) forControlEvents:UIControlEventTouchUpInside];

    // Tap handler using UIControl event + C function
    [gLogo addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
        TogglePanel();
    }] forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc] initWithTarget:[NSValue valueWithPointer:(const void *)HandleDrag]
                                               action:@selector(pointerValue)];
    // simpler: use target = gContainer and call C function via block
    pan = [[UIPanGestureRecognizer alloc] initWithTarget:nil action:nil];
    [pan addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
        HandleDrag((UIPanGestureRecognizer *)action.sender);
    }]];
    [gLogo addGestureRecognizer:pan];

    [gContainer addSubview:gLogo];

    // Panel
    CGFloat W = 280, H = 260;
    gPanel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, H)];
    gPanel.center = CGPointMake(gLogo.center.x + W/2 + 10, gLogo.center.y);
    gPanel.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.98];
    gPanel.layer.cornerRadius = 16;
    gPanel.hidden = YES;
    gPanel.alpha = 0.0;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(12, 10, W-24, 24)];
    title.text = @"Arcasa Menu";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    [gPanel addSubview:title];

    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 42, W, 1)];
    line.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    [gPanel addSubview:line];

    AddToggle(gPanel, @"God Mode", 58, gGodMode, @selector(toggleGod:), gHandlers);
    AddToggle(gPanel, @"Wallhack", 110, gWallhack, @selector(toggleWall:), gHandlers);
    AddToggle(gPanel, @"Aimbot", 162, gAimbot, @selector(toggleAim:), gHandlers);

    UILabel *speedLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 210, 120, 20)];
    speedLabel.text = @"Speed";
    speedLabel.textColor = UIColor.whiteColor;
    speedLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [gPanel addSubview:speedLabel];

    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(12, 232, W-24, 18)];
    slider.minimumValue = 0.5;
    slider.maximumValue = 3.0;
    slider.value = gSpeed;
    [slider addTarget:gHandlers action:@selector(speedChanged:) forControlEvents:UIControlEventValueChanged];
    [gPanel addSubview:slider];

    [gContainer addSubview:gPanel];

    // Wire passthrough targets
    gContainer.logoView = gLogo;
    gContainer.panelView = gPanel;

    // Add to window
    [window addSubview:gContainer];
    [window bringSubviewToFront:gContainer];
}

static void TogglePanel(void) {
    gPanelVisible = !gPanelVisible;

    if (gPanelVisible) {
        gPanel.hidden = NO;
        gPanel.alpha = 0.0;
        gPanel.transform = CGAffineTransformMakeScale(0.96, 0.96);

        [UIView animateWithDuration:0.18 animations:^{
            gPanel.alpha = 1.0;
            gPanel.transform = CGAffineTransformIdentity;
        }];
    } else {
        [UIView animateWithDuration:0.15 animations:^{
            gPanel.alpha = 0.0;
            gPanel.transform = CGAffineTransformMakeScale(0.96, 0.96);
        } completion:^(BOOL finished) {
            gPanel.hidden = YES;
        }];
    }
}

#pragma mark - Retry until window exists

static void BuildUIWithRetry(int triesLeft) {
    if (triesLeft <= 0) return;

    UIWindow *window = FindKeyWindow();
    if (!window || !window.rootViewController) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            BuildUIWithRetry(triesLeft - 1);
        });
        return;
    }

    BuildUI(window);
}

#pragma mark - Entry (on dylib load)

__attribute__((constructor))
static void dylib_entry(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        BuildUIWithRetry(25); // ~6 seconds max
    });
}