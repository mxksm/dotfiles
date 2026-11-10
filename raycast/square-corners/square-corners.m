#import <AppKit/AppKit.h>
#import <objc/runtime.h>

static CGFloat squareRadius(id self, SEL cmd) { return 0; }
static void installHooks(void) {
    Class frame = NSClassFromString(@"NSThemeFrame");
    const char *names[] = {"_cornerRadius", "_getCachedDefaultWindowCornerRadius", "raycast_NSThemeFrame_cornerRadius"};
    for (unsigned i = 0; i < 3; i++) {
        SEL sel = sel_registerName(names[i]);
        Method method = class_getInstanceMethod(frame, sel);
        if (method) {
            class_addMethod(frame, sel, (IMP)squareRadius, method_getTypeEncoding(method));
            method_setImplementation(class_getInstanceMethod(frame, sel), (IMP)squareRadius);
        }
    }
}
__attribute__((constructor)) static void init(void) {
    if (strcmp(getprogname(), "Raycast") != 0) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        installHooks();
        [[NSNotificationCenter defaultCenter] addObserverForName:NSWindowDidBecomeKeyNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            installHooks();
            NSWindow *window = note.object;
            SEL setter = NSSelectorFromString(@"_setCornerRadius:");
            if ([window respondsToSelector:setter]) {
                ((void (*)(id, SEL, CGFloat))[window methodForSelector:setter])(window, setter, 0);
            }
            [window invalidateShadow];
        }];
    });
}
