#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <dlfcn.h>
#import <sys/types.h>

// --- دالة التشفير وفك التشفير الديناميكية للنصوص ---
static inline NSString *secStr(const unsigned char *data, size_t len, unsigned char key) {
    char *outData = (char *)malloc(len + 1);
    if (!outData) return @"";
    for (size_t i = 0; i < len; i++) {
        outData[i] = data[i] ^ key;
    }
    outData[len] = '\0';
    NSString *result = [NSString stringWithUTF8String:outData];
    free(outData);
    return result ? result : @"";
}

// مفاتيح الحفظ في NSUserDefaults مشفرة
static inline NSString *getKeyTimestamp(void) {
    const unsigned char b[] = {0x0B, 0x3A, 0x3A, 0x0B, 0x29, 0x3E, 0x23, 0x3C, 0x2B, 0x3E, 0x23, 0x25, 0x24, 0x1E, 0x23, 0x27, 0x2F, 0x39, 0x3E, 0x2B, 0x27, 0x3A};
    return secStr(b, sizeof(b), 0x4A);
}

static inline NSString *getKeyDuration(void) {
    const unsigned char b[] = {0x0B, 0x3A, 0x3A, 0x0B, 0x29, 0x3E, 0x23, 0x3C, 0x2B, 0x3E, 0x23, 0x25, 0x24, 0x0E, 0x3F, 0x38, 0x2B, 0x3E, 0x23, 0x25, 0x24, 0x0E, 0x2B, 0x33, 0x39};
    return secStr(b, sizeof(b), 0x4A);
}

static inline NSString *getKeyActivatedCode(void) {
    const unsigned char b[] = {0x0B, 0x3A, 0x3A, 0x0B, 0x29, 0x3E, 0x23, 0x3C, 0x2B, 0x3E, 0x23, 0x25, 0x24, 0x09, 0x2F, 0x2E, 0x21, 0x25, 0x2E, 0x21};
    return secStr(b, sizeof(b), 0x4A);
}

// رابط سيرفر المفاتيح مشفر
static inline NSString *getApiUrl(void) {
    const unsigned char b[] = {
        0x22, 0x3E, 0x3E, 0x3A, 0x39, 0x70, 0x65, 0x65, 0x38, 0x2B, 0x3D, 0x64, 0x2D, 0x23, 0x3E, 0x22,
        0x3F, 0x28, 0x3F, 0x39, 0x2F, 0x38, 0x29, 0x25, 0x24, 0x3E, 0x2F, 0x24, 0x3E, 0x64, 0x29, 0x25,
        0x27, 0x65, 0x0B, 0x27, 0x2B, 0x38, 0x33, 0x3E, 0x7B, 0x65, 0x0B, 0x65, 0x38, 0x2F, 0x2C, 0x39,
        0x65, 0x22, 0x2F, 0x2B, 0x2E, 0x39, 0x65, 0x27, 0x2B, 0x23, 0x24, 0x65, 0x3A, 0x3F, 0x28, 0x26,
        0x23, 0x29, 0x65, 0x21, 0x2F, 0x33, 0x39, 0x64, 0x20, 0x39, 0x25, 0x24
    };
    return secStr(b, sizeof(b), 0x4A);
}

// رابط التليجرام مشفر
static inline NSString *getTelegramUrl(void) {
    const unsigned char b[] = {
        0x22, 0x3E, 0x3E, 0x3A, 0x39, 0x70, 0x65, 0x65, 0x3E, 0x2F, 0x26, 0x2F, 0x2D, 0x38, 0x2B, 0x27,
        0x64, 0x27, 0x2F, 0x65, 0x06, 0x06, 0x13, 0x0E, 0x06
    };
    return secStr(b, sizeof(b), 0x4A);
}

// حماية ضد التصحيح والتتبع Dynamic Anti-Debugging
typedef int (*ptrace_ptr_t)(int _request, pid_t _pid, caddr_t _addr, int _data);
static void applyAntiDebugging(void) {
    void* handle = dlopen(NULL, RTLD_GLOBAL | RTLD_NOW);
    if (handle) {
        ptrace_ptr_t ptrace_func = (ptrace_ptr_t)dlsym(handle, "ptrace");
        if (ptrace_func) {
            ptrace_func(31, 0, 0, 0); // PT_DENY_ATTACH
        }
        dlclose(handle);
    }
}

@interface AppLockViewController : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) UIView *cardContainerView;
@property (nonatomic, strong) UIImageView *headerIconView;
@property (nonatomic, strong) UITextField *passcodeTextField;
@property (nonatomic, strong) UIButton *submitButton;
@property (nonatomic, strong) UIButton *telegramButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIProgressView *timerProgressView;

@property (nonatomic, strong) NSTimer *autoExitTimer;
@property (nonatomic, assign) NSTimeInterval remainingTime;

+ (BOOL)isSubscriptionValid;
+ (NSString *)remainingTimeString;
+ (void)showSuccessNotificationOnVC:(UIViewController *)vc;
+ (void)syncSubscriptionWithServer;
@end

@implementation AppLockViewController

+ (BOOL)isSubscriptionValid {
    NSTimeInterval activatedTime = [[NSUserDefaults standardUserDefaults] doubleForKey:getKeyTimestamp()];
    double durationDays = [[NSUserDefaults standardUserDefaults] doubleForKey:getKeyDuration()];
    
    if (activatedTime <= 0 || durationDays <= 0) return NO;
    
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval allowedDuration = durationDays * 86400.0;
    
    return (currentTime - activatedTime) < allowedDuration;
}

+ (NSString *)remainingTimeString {
    NSTimeInterval activatedTime = [[NSUserDefaults standardUserDefaults] doubleForKey:getKeyTimestamp()];
    double durationDays = [[NSUserDefaults standardUserDefaults] doubleForKey:getKeyDuration()];
    if (activatedTime <= 0 || durationDays <= 0) return @"منتهي الصلاحية";
    
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval allowedDuration = durationDays * 86400.0;
    NSTimeInterval remaining = allowedDuration - (currentTime - activatedTime);
    
    if (remaining <= 0) return @"منتهي الصلاحية";
    
    NSInteger days = (NSInteger)(remaining / 86400.0);
    NSInteger hours = (NSInteger)((remaining - (days * 86400)) / 3600.0);
    NSInteger minutes = (NSInteger)((remaining - (days * 86400) - (hours * 3600)) / 60.0);
    NSInteger seconds = (NSInteger)(remaining) % 60;
    
    NSMutableArray *parts = [NSMutableArray array];
    if (days > 0) [parts addObject:[NSString stringWithFormat:@"%ld يوم", (long)days]];
    if (hours > 0) [parts addObject:[NSString stringWithFormat:@"%ld ساعة", (long)hours]];
    if (minutes > 0) [parts addObject:[NSString stringWithFormat:@"%ld دقيقة", (long)minutes]];
    [parts addObject:[NSString stringWithFormat:@"%ld ثانية", (long)seconds]];
    
    return [parts componentsJoinedByString:@" و "];
}

+ (void)showSuccessNotificationOnVC:(UIViewController *)vc {
    if (!vc) return;
    NSString *remainingText = [self remainingTimeString];
    NSString *message = [NSString stringWithFormat:@"اشتراكك فعال بنجاح!\nالمتبقي: %@", remainingText];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"✅ حالة الاشتراك"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];
    [vc presentViewController:alert animated:YES completion:nil];
}

+ (void)syncSubscriptionWithServer {
    NSString *savedCode = [[NSUserDefaults standardUserDefaults] stringForKey:getKeyActivatedCode()];
    if (!savedCode || savedCode.length == 0) return;
    
    NSURL *url = [NSURL URLWithString:getApiUrl()];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                            cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                        timeoutInterval:10.0];
    [request setHTTPMethod:@"GET"];
    [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1" forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"application/json, text/plain, */*" forHTTPHeaderField:@"Accept"];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) return;
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode != 200) return;
        
        NSError *jsonError;
        id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError) return;
        
        BOOL isStillValid = NO;
        double newDurationDays = 30.0;
        
        if ([jsonObject isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = (NSDictionary *)jsonObject;
            NSArray *details = dict[@"details"];
            if ([details isKindOfClass:[NSArray class]]) {
                for (id item in details) {
                    if ([item isKindOfClass:[NSDictionary class]]) {
                        NSString *k = item[@"code"] ?: item[@"key"];
                        if (k && [k isEqualToString:savedCode]) {
                            isStillValid = YES;
                            double customDays = [item[@"days"] doubleValue];
                            if (customDays > 0) newDurationDays = customDays;
                            break;
                        }
                    }
                }
            }
            if (!isStillValid) {
                NSArray *validKeys = dict[@"valid_keys"];
                if ([validKeys isKindOfClass:[NSArray class]] && [validKeys containsObject:savedCode]) {
                    isStillValid = YES;
                }
            }
        } else if ([jsonObject isKindOfClass:[NSArray class]]) {
            NSArray *array = (NSArray *)jsonObject;
            if ([array containsObject:savedCode]) {
                isStillValid = YES;
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (isStillValid) {
                [[NSUserDefaults standardUserDefaults] setDouble:newDurationDays forKey:getKeyDuration()];
                [[NSUserDefaults standardUserDefaults] synchronize];
            } else {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:getKeyTimestamp()];
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:getKeyDuration()];
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:getKeyActivatedCode()];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                UIWindow *window = nil;
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Wdeprecated-declarations"
                window = [UIApplication sharedApplication].keyWindow;
                #pragma clang diagnostic pop
                if (!window && [UIApplication sharedApplication].windows.count > 0) {
                    window = [UIApplication sharedApplication].windows.firstObject;
                }
                if (window) {
                    UIViewController *rootVC = window.rootViewController;
                    while (rootVC.presentedViewController) {
                        rootVC = rootVC.presentedViewController;
                    }
                    if (![rootVC isKindOfClass:[AppLockViewController class]]) {
                        AppLockViewController *lockVC = [[AppLockViewController alloc] init];
                        lockVC.modalPresentationStyle = UIModalPresentationFullScreen;
                        [rootVC presentViewController:lockVC animated:NO completion:nil];
                    }
                }
            }
        });
    }];
    [task resume];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    
    // 1. خلفية الضباب
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurEffectView.frame = self.view.bounds;
    blurEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:blurEffectView];
    
    CGFloat screenWidth = self.view.bounds.size.width;
    CGFloat cardWidth = MIN(screenWidth - 40, 350);
    CGFloat cardHeight = 440;
    
    // 2. بطاقة زجاجية (Glassmorphism Container)
    self.cardContainerView = [[UIView alloc] initWithFrame:CGRectMake((screenWidth - cardWidth) / 2, (self.view.bounds.size.height - cardHeight) / 2, cardWidth, cardHeight)];
    self.cardContainerView.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.75];
    self.cardContainerView.layer.cornerRadius = 22;
    self.cardContainerView.layer.borderWidth = 1.0;
    self.cardContainerView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;
    self.cardContainerView.clipsToBounds = YES;
    [self.view addSubview:self.cardContainerView];
    
    // 3. شريط العد التنازلي التفاعلي (15 ثانية)
    self.timerProgressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.timerProgressView.frame = CGRectMake(0, 0, cardWidth, 4);
    self.timerProgressView.progressTintColor = [UIColor systemBlueColor];
    self.timerProgressView.trackTintColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    self.timerProgressView.progress = 1.0;
    [self.cardContainerView addSubview:self.timerProgressView];
    
    // 4. شعار / أيقونة القفل
    self.headerIconView = [[UIImageView alloc] initWithFrame:CGRectMake((cardWidth - 54) / 2, 25, 54, 54)];
    if (@available(iOS 13.0, *)) {
        self.headerIconView.image = [UIImage systemImageNamed:@"lock.shield.fill"];
        self.headerIconView.tintColor = [UIColor systemBlueColor];
    }
    self.headerIconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.cardContainerView addSubview:self.headerIconView];
    
    // 5. العنوان الرئيسية
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 90, cardWidth - 30, 30)];
    titleLabel.text = @"تفعيل الاشتراك";
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [self.cardContainerView addSubview:titleLabel];
    
    // 6. نص الحالة والأخطاء
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 125, cardWidth - 30, 25)];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.textColor = [UIColor systemRedColor];
    self.statusLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [self.cardContainerView addSubview:self.statusLabel];
    
    // 7. حقل النص الإدخال + زر اللصق السريع
    self.passcodeTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 160, cardWidth - 40, 50)];
    self.passcodeTextField.placeholder = @"أدخل كود التفعيل";
    self.passcodeTextField.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    self.passcodeTextField.layer.cornerRadius = 12;
    self.passcodeTextField.layer.borderWidth = 1.0;
    self.passcodeTextField.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.15].CGColor;
    self.passcodeTextField.textColor = [UIColor whiteColor];
    self.passcodeTextField.secureTextEntry = YES;
    self.passcodeTextField.textAlignment = NSTextAlignmentCenter;
    
    // زر اللصق داخل حقل النص
    UIButton *pasteBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    pasteBtn.frame = CGRectMake(0, 0, 45, 50);
    if (@available(iOS 13.0, *)) {
        [pasteBtn setImage:[UIImage systemImageNamed:@"doc.on.clipboard"] forState:UIControlStateNormal];
    } else {
        [pasteBtn setTitle:@"لصق" forState:UIControlStateNormal];
    }
    pasteBtn.tintColor = [UIColor systemBlueColor];
    [pasteBtn addTarget:self action:@selector(pasteFromClipboard) forControlEvents:UIControlEventTouchUpInside];
    
    self.passcodeTextField.rightView = pasteBtn;
    self.passcodeTextField.rightViewMode = UITextFieldViewModeAlways;
    [self.cardContainerView addSubview:self.passcodeTextField];
    
    // 8. زر التحقق والتفعيل
    self.submitButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.submitButton.frame = CGRectMake(20, 230, cardWidth - 40, 50);
    [self.submitButton setTitle:@"تحقق وتفعيل" forState:UIControlStateNormal];
    self.submitButton.backgroundColor = [UIColor systemBlueColor];
    [self.submitButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.submitButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.submitButton.layer.cornerRadius = 12;
    [self.submitButton addTarget:self action:@selector(verifyCode) forControlEvents:UIControlEventTouchUpInside];
    [self.cardContainerView addSubview:self.submitButton];
    
    // 9. زر الدعم عبر تليجرام
    self.telegramButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.telegramButton.frame = CGRectMake(20, 295, cardWidth - 40, 45);
    [self.telegramButton setTitle:@"✈️ الدعم عبر تليجرام" forState:UIControlStateNormal];
    self.telegramButton.backgroundColor = [UIColor colorWithRed:0.0/255.0 green:136.0/255.0 blue:204.0/255.0 alpha:0.85];
    [self.telegramButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.telegramButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.telegramButton.layer.cornerRadius = 12;
    [self.telegramButton addTarget:self action:@selector(openTelegram) forControlEvents:UIControlEventTouchUpInside];
    [self.cardContainerView addSubview:self.telegramButton];
    
    // 10. مؤشر التحميل
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.center = CGPointMake(cardWidth / 2, 375);
    self.spinner.color = [UIColor whiteColor];
    [self.cardContainerView addSubview:self.spinner];
    
    // بدء العداد التنازلي (15 ثانية)
    self.remainingTime = 15.0;
    self.autoExitTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                     target:self
                                                   selector:@selector(updateCountdownProgress)
                                                   userInfo:nil
                                                    repeats:YES];
}

// زر اللصق السريع
- (void)pasteFromClipboard {
    [self triggerHapticFeedback:UIImpactFeedbackStyleLight];
    NSString *clipboardString = [UIPasteboard generalPasteboard].string;
    if (clipboardString && clipboardString.length > 0) {
        self.passcodeTextField.text = [clipboardString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
}

// تحديث شريط التقدم كل 0.1 ثانية والإنهاء بعد 15 ثانية
- (void)updateCountdownProgress {
    self.remainingTime -= 0.1;
    float progress = MAX(0.0, self.remainingTime / 15.0);
    [self.timerProgressView setProgress:progress animated:YES];
    
    if (self.remainingTime <= 0) {
        [self.autoExitTimer invalidate];
        exit(0);
    }
}

// تأثير الاهتزاز التفاعلي (Haptic)
- (void)triggerHapticNotification:(UINotificationFeedbackType)type {
    if (@available(iOS 10.0, *)) {
        UINotificationFeedbackGenerator *generator = [[UINotificationFeedbackGenerator alloc] init];
        [generator prepare];
        [generator notificationOccurred:type];
    }
}

- (void)triggerHapticFeedback:(UIImpactFeedbackStyle)style {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:style];
        [generator prepare];
        [generator impactOccurred];
    }
}

// تأثير اهتزاز حقل النص عند الخطأ (Shake Animation)
- (void)shakeView:(UIView *)viewToShake {
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    animation.duration = 0.4;
    animation.values = @[ @(-10), @(10), @(-8), @(8), @(-4), @(4), @(0) ];
    [viewToShake.layer addAnimation:animation forKey:@"shake"];
}

- (void)openTelegram {
    [self triggerHapticFeedback:UIImpactFeedbackStyleMedium];
    NSURL *telegramURL = [NSURL URLWithString:getTelegramUrl()];
    [[UIApplication sharedApplication] openURL:telegramURL options:@{} completionHandler:nil];
}

- (void)dealloc {
    [self.autoExitTimer invalidate];
}

- (void)verifyCode {
    [self triggerHapticFeedback:UIImpactFeedbackStyleMedium];
    
    NSString *code = [self.passcodeTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (code.length == 0) {
        [self triggerHapticNotification:UINotificationFeedbackTypeError];
        [self shakeView:self.passcodeTextField];
        self.statusLabel.text = @"يرجى إدخال كود التفعيل أولاً";
        return;
    }
    
    [self.spinner startAnimating];
    self.submitButton.enabled = NO;
    self.statusLabel.text = @"جاري الاتصال باللوحة...";
    
    NSURL *url = [NSURL URLWithString:getApiUrl()];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                            cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                        timeoutInterval:10.0];
    [request setHTTPMethod:@"GET"];
    [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1" forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"application/json, text/plain, */*" forHTTPHeaderField:@"Accept"];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            self.submitButton.enabled = YES;
            
            if (error || !data) {
                [self triggerHapticNotification:UINotificationFeedbackTypeError];
                [self shakeView:self.cardContainerView];
                self.statusLabel.text = @"تعذر الاتصال بقائمة المفاتيح";
                return;
            }
            
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode != 200) {
                [self triggerHapticNotification:UINotificationFeedbackTypeError];
                [self shakeView:self.cardContainerView];
                self.statusLabel.text = [NSString stringWithFormat:@"خطأ سيرفر رمز: %ld", (long)httpResponse.statusCode];
                return;
            }
            
            NSError *jsonError;
            id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (jsonError) {
                [self triggerHapticNotification:UINotificationFeedbackTypeError];
                [self shakeView:self.cardContainerView];
                self.statusLabel.text = @"خطأ في قراءة ملف المفاتيح من السيرفر";
                return;
            }
            
            BOOL isValidKey = NO;
            double durationDays = 30.0;
            
            if ([jsonObject isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dict = (NSDictionary *)jsonObject;
                
                NSArray *details = dict[@"details"];
                if ([details isKindOfClass:[NSArray class]]) {
                    for (id item in details) {
                        if ([item isKindOfClass:[NSDictionary class]]) {
                            NSString *k = item[@"code"] ?: item[@"key"];
                            if (k && [k isEqualToString:code]) {
                                isValidKey = YES;
                                double customDays = [item[@"days"] doubleValue];
                                if (customDays > 0) durationDays = customDays;
                                break;
                            }
                        }
                    }
                }
                
                if (!isValidKey) {
                    NSArray *validKeys = dict[@"valid_keys"];
                    if ([validKeys isKindOfClass:[NSArray class]] && [validKeys containsObject:code]) {
                        isValidKey = YES;
                    }
                }
            } else if ([jsonObject isKindOfClass:[NSArray class]]) {
                NSArray *array = (NSArray *)jsonObject;
                if ([array containsObject:code]) {
                    isValidKey = YES;
                }
            }
            
            if (isValidKey) {
                [self.autoExitTimer invalidate];
                self.autoExitTimer = nil;
                [self triggerHapticNotification:UINotificationFeedbackTypeSuccess];
                
                NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
                [[NSUserDefaults standardUserDefaults] setDouble:now forKey:getKeyTimestamp()];
                [[NSUserDefaults standardUserDefaults] setDouble:durationDays forKey:getKeyDuration()];
                [[NSUserDefaults standardUserDefaults] setObject:code forKey:getKeyActivatedCode()];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                UIViewController *presentingVC = self.presentingViewController;
                [self dismissViewControllerAnimated:YES completion:^{
                    if (presentingVC) {
                        [AppLockViewController showSuccessNotificationOnVC:presentingVC];
                    }
                }];
            } else {
                [self triggerHapticNotification:UINotificationFeedbackTypeError];
                [self shakeView:self.passcodeTextField];
                self.statusLabel.text = @"الكود غير صحيح أو منتهي الصلاحية";
            }
        });
    }];
    [task resume];
}

@end

static void showLockScreenIfNeeded(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        window = [UIApplication sharedApplication].keyWindow;
        #pragma clang diagnostic pop
        
        if (!window && [UIApplication sharedApplication].windows.count > 0) {
            window = [UIApplication sharedApplication].windows.firstObject;
        }
        
        if (window) {
            UIViewController *rootVC = window.rootViewController;
            while (rootVC.presentedViewController) {
                rootVC = rootVC.presentedViewController;
            }
            
            if (![AppLockViewController isSubscriptionValid]) {
                AppLockViewController *lockVC = [[AppLockViewController alloc] init];
                lockVC.modalPresentationStyle = UIModalPresentationFullScreen;
                [rootVC presentViewController:lockVC animated:NO completion:nil];
            } else {
                [AppLockViewController showSuccessNotificationOnVC:rootVC];
                [AppLockViewController syncSubscriptionWithServer];
            }
        }
    });
}

static void __attribute__((constructor)) initializeAppLock(void) {
    // إطلاق الحماية ضد أدوات التصحيح (Anti-Debug)
    applyAntiDebugging();

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        showLockScreenIfNeeded();
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        showLockScreenIfNeeded();
    }];
}
