#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

#pragma mark - Scene-safe window + top VC (iOS 13+ / iOS 18 safe)

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

static UIViewController *TopVC(UIViewController *root) {
    UIViewController *vc = root;
    while (vc.presentedViewController) vc = vc.presentedViewController;

    if ([vc isKindOfClass:[UINavigationController class]]) {
        return TopVC(((UINavigationController *)vc).topViewController);
    }
    if ([vc isKindOfClass:[UITabBarController class]]) {
        return TopVC(((UITabBarController *)vc).selectedViewController);
    }
    return vc;
}

#pragma mark - Example state vars (connect these to your features)

static BOOL gGodMode = NO;
static BOOL gWallhack = NO;
static BOOL gAimbot = NO;
static float gSpeed = 1.0f;

#pragma mark - Overlay Controller

@interface CheatOverlayController : UIViewController
@property (nonatomic, strong) UIButton *fab;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, assign) BOOL panelVisible;
@end

@implementation CheatOverlayController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.panelVisible = NO;

    [self buildFloatingButton];
    [self buildPanel];
}

#pragma mark UI build

- (void)buildFloatingButton {
    CGFloat size = 64;

    self.fab = [UIButton buttonWithType:UIButtonTypeCustom];
    self.fab.frame = CGRectMake(40, 120, size, size);
    self.fab.layer.cornerRadius = size/2;
    self.fab.backgroundColor = [UIColor colorWithRed:0.8 green:0.1 blue:0.9 alpha:0.95];

    [self.fab setTitle:@"☰" forState:UIControlStateNormal];
    self.fab.titleLabel.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBold];

    self.fab.layer.shadowColor = UIColor.blackColor.CGColor;
    self.fab.layer.shadowOpacity = 0.35;
    self.fab.layer.shadowRadius = 8;
    self.fab.layer.shadowOffset = CGSizeMake(0, 4);

    [self.fab addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDrag:)];
    [self.fab addGestureRecognizer:pan];

    [self.view addSubview:self.fab];
}

- (void)buildPanel {
    CGFloat W = 280, H = 260;

    self.panel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, H)];
    self.panel.center = CGPointMake(self.fab.center.x + W/2 + 10, self.fab.center.y);
    self.panel.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.98];
    self.panel.layer.cornerRadius = 16;
    self.panel.hidden = YES;

    self.panel.layer.shadowColor = UIColor.blackColor.CGColor;
    self.panel.layer.shadowOpacity = 0.5;
    self.panel.layer.shadowRadius = 10;
    self.panel.layer.shadowOffset = CGSizeMake(0, 6);

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(12, 10, W-24, 24)];
    title.text = @"Arcasa Menu";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    [self.panel addSubview:title];

    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 42, W, 1)];
    line.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    [self.panel addSubview:line];

    UISwitch *sw1 = [self addToggle:@"God Mode" y:58 initial:gGodMode action:@selector(toggleGod:)];
    UISwitch *sw2 = [self addToggle:@"Wallhack" y:110 initial:gWallhack action:@selector(toggleWall:)];
    UISwitch *sw3 = [self addToggle:@"Aimbot" y:162 initial:gAimbot action:@selector(toggleAim:)];

    UILabel *speedLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 210, 120, 20)];
    speedLabel.text = @"Speed";
    speedLabel.textColor = UIColor.whiteColor;
    speedLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [self.panel addSubview:speedLabel];

    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(12, 232, W-24, 18)];
    slider.minimumValue = 0.5;
    slider.maximumValue = 3.0;
    slider.value = gSpeed;
    [slider addTarget:self action:@selector(speedChanged:) forControlEvents:UIControlEventValueChanged];
    [self.panel addSubview:slider];

    sw1.onTintColor = self.fab.backgroundColor;
    sw2.onTintColor = self.fab.backgroundColor;
    sw3.onTintColor = self.fab.backgroundColor;

    [self.view addSubview:self.panel];
}

- (UISwitch *)addToggle:(NSString *)name y:(CGFloat)y initial:(BOOL)initial action:(SEL)action {
    CGFloat W = self.panel.bounds.size.width;

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(12, y, 180, 24)];
    label.text = name;
    label.textColor = UIColor.whiteColor;
    label.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
    [self.panel addSubview:label];

    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectZero];
    sw.on = initial;
    sw.center = CGPointMake(W - 40, y + 12);
    [sw addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    [self.panel addSubview:sw];

    return sw;
}

#pragma mark - Interactions

- (void)togglePanel {
    self.panelVisible = !self.panelVisible;

    if (self.panelVisible) {
        self.panel.hidden = NO;
        self.panel.alpha = 0.0;
        self.panel.transform = CGAffineTransformMakeScale(0.96, 0.96);

        [UIView animateWithDuration:0.18 animations:^{
            self.panel.alpha = 1.0;
            self.panel.transform = CGAffineTransformIdentity;
        }];
    } else {
        [UIView animateWithDuration:0.15 animations:^{
            self.panel.alpha = 0.0;
            self.panel.transform = CGAffineTransformMakeScale(0.96, 0.96);
        } completion:^(BOOL finished) {
            self.panel.hidden = YES;
        }];
    }
}

- (void)handleDrag:(UIPanGestureRecognizer *)pan {
    CGPoint t = [pan translationInView:self.view];
    pan.view.center = CGPointMake(pan.view.center.x + t.x, pan.view.center.y + t.y);
    [pan setTranslation:CGPointZero inView:self.view];

    CGFloat W = self.panel.bounds.size.width;
    self.panel.center = CGPointMake(self.fab.center.x + W/2 + 10, self.fab.center.y);

    if (pan.state == UIGestureRecognizerStateEnded) {
        UIWindow *win = self.view.window;
        if (!win) return;

        CGFloat left = 20 + self.fab.bounds.size.width/2;
        CGFloat right = win.bounds.size.width - left;

        CGFloat targetX = (self.fab.center.x < win.bounds.size.width/2) ? left : right;

        [UIView animateWithDuration:0.2 animations:^{
            self.fab.center = CGPointMake(targetX, self.fab.center.y);
            self.panel.center = CGPointMake(self.fab.center.x + W/2 + 10, self.fab.center.y);
        }];
    }
}

#pragma mark - Toggle handlers

- (void)toggleGod:(UISwitch *)sw {
    gGodMode = sw.isOn;
    NSLog(@"[dylib] God Mode = %@", gGodMode ? @"ON" : @"OFF");
}

- (void)toggleWall:(UISwitch *)sw {
    gWallhack = sw.isOn;
    NSLog(@"[dylib] Wallhack = %@", gWallhack ? @"ON" : @"OFF");
}

- (void)toggleAim:(UISwitch *)sw {
    gAimbot = sw.isOn;
    NSLog(@"[dylib] Aimbot = %@", gAimbot ? @"ON" : @"OFF");
}

- (void)speedChanged:(UISlider *)sl {
    gSpeed = sl.value;
    NSLog(@"[dylib] Speed = %.2f", gSpeed);
}

@end

#pragma mark - Entry point (runs when dylib loads)

__attribute__((constructor))
static void dylib_entry(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = FindKeyWindow();
        if (!window) return;

        UIViewController *root = window.rootViewController;
        if (!root) return;

        UIViewController *top = TopVC(root);

        CheatOverlayController *overlay = [CheatOverlayController new];
        overlay.modalPresentationStyle = UIModalPresentationOverFullScreen;

        [top presentViewController:overlay animated:NO completion:nil];
    });
}
