#import <UIKit/UIKit.h>

#pragma mark - Helpers (iOS 13+ scenes safe)

static UIWindow *FindKeyWindow(void) {
    NSSet<UIScene *> *scenes = UIApplication.sharedApplication.connectedScenes;
    for (UIScene *scene in scenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive) continue;
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;

        UIWindowScene *ws = (UIWindowScene *)scene;
        for (UIWindow *w in ws.windows) {
            if (w.isKeyWindow) return w;
        }
        // fallback: first visible window
        for (UIWindow *w in ws.windows) {
            if (!w.hidden && w.alpha > 0.0) return w;
        }
    }
    return nil;
}

static UIViewController *TopViewController(UIViewController *root) {
    UIViewController *vc = root;
    while (vc.presentedViewController) {
        vc = vc.presentedViewController;
    }
    // handle nav/tab containers
    if ([vc isKindOfClass:[UINavigationController class]]) {
        return TopViewController(((UINavigationController *)vc).topViewController);
    }
    if ([vc isKindOfClass:[UITabBarController class]]) {
        return TopViewController(((UITabBarController *)vc).selectedViewController);
    }
    return vc;
}

#pragma mark - UI Controller

@interface MyUIController : UIViewController
@end

@implementation MyUIController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];

    CGFloat W = 300, H = 160;
    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, H)];
    panel.center = self.view.center;
    panel.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];
    panel.layer.cornerRadius = 18;
    [self.view addSubview:panel];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, W, 40)];
    label.text = @"Hello from iOS 18 dylib!";
    label.textColor = UIColor.whiteColor;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    [panel addSubview:label];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake((W-140)/2, 80, 140, 44);
    [closeBtn setTitle:@"Close" forState:UIControlStateNormal];
    closeBtn.tintColor = UIColor.whiteColor;
    closeBtn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    closeBtn.layer.cornerRadius = 10;
    [closeBtn addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:closeBtn];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

#pragma mark - Entry (runs on load)

__attribute__((constructor))
static void dylib_entry(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = FindKeyWindow();
        if (!window) return;

        UIViewController *root = window.rootViewController;
        if (!root) return;

        UIViewController *top = TopViewController(root);

        MyUIController *vc = [MyUIController new];
        vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
        vc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;

        [top presentViewController:vc animated:YES completion:nil];
    });
}
