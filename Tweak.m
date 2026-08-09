#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface AppLockViewController : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *passcodeTextField;
@property (nonatomic, strong) UIButton *submitButton;
@property (nonatomic, strong) UIButton *telegramButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) NSTimer *autoExitTimer;

+ (BOOL)isSubscriptionValid;
+ (NSString *)remainingTimeString;
+ (void)showSuccessNotificationOnVC:(UIViewController *)vc;
+ (void)syncSubscriptionWithServer;
@end

@implementation AppLockViewController

// 1. فحص صلاحية الاشتراك محلياً
+ (BOOL)isSubscriptionValid {
    NSTimeInterval activatedTime = [[NSUserDefaults standardUserDefaults] doubleForKey:@"AppActivationTimestamp"];
    double durationDays = [[NSUserDefaults standardUserDefaults] doubleForKey:@"AppActivationDurationDays"];
    
    if (activatedTime <= 0 || durationDays <= 0) return NO;
    
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval allowedDuration = durationDays * 86400.0;
    
    return (currentTime - activatedTime) < allowedDuration;
}

// 2. حساب الوقت المتبقي باليوم والدقيقة والساعة والثانية
+ (NSString *)remainingTimeString {
    NSTimeInterval activatedTime = [[NSUserDefaults standardUserDefaults] doubleForKey:@"AppActivationTimestamp"];
    double durationDays = [[NSUserDefaults standardUserDefaults] doubleForKey:@"AppActivationDurationDays"];
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

// إظهار إشعار حالة الاشتراك
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

// 3. مزامنة البيانات وتحديث الأيام تلقائياً من السيرفر عند دخول المستخدم
+ (void)syncSubscriptionWithServer {
    NSString *savedCode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppActivatedCode"];
    if (!savedCode || savedCode.length == 0) return;
    
    NSURL *url = [NSURL URLWithString:@"https://raw.githubusercontent.com/Amaryt1/A/refs/heads/main/public/keys.json"];
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
                // تحديث الأيام بالقيم الجديدة القادمة من keys.json فوراً
                [[NSUserDefaults standardUserDefaults] setDouble:newDurationDays forKey:@"AppActivationDurationDays"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            } else {
                // إذا حُذف الكود من السيرفر يتم سحب التفعيل وإعادة إظهار القفل
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AppActivationTimestamp"];
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AppActivationDurationDays"];
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AppActivatedCode"];
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
    
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurEffectView.frame = self.view.bounds;
    blurEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:blurEffectView];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 140, self.view.bounds.size.width - 40, 40)];
    titleLabel.text = @"التطبيق محمي بكلمة مرور";
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [self.view addSubview:titleLabel];
    
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 190, self.view.bounds.size.width - 40, 30)];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.textColor = [UIColor systemRedColor];
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    [self.view addSubview:self.statusLabel];
    
    self.passcodeTextField = [[UITextField alloc] initWithFrame:CGRectMake(40, 230, self.view.bounds.size.width - 80, 50)];
    self.passcodeTextField.placeholder = @"أدخل كود التفعيل";
    self.passcodeTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.passcodeTextField.secureTextEntry = YES;
    self.passcodeTextField.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.passcodeTextField];
    
    // زر تحقق وتفعيل
    self.submitButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.submitButton.frame = CGRectMake(40, 295, self.view.bounds.size.width - 80, 50);
    [self.submitButton setTitle:@"تحقق وتفعيل" forState:UIControlStateNormal];
    self.submitButton.backgroundColor = [UIColor systemBlueColor];
    [self.submitButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.submitButton.layer.cornerRadius = 10;
    [self.submitButton addTarget:self action:@selector(verifyCode) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.submitButton];
    
    // زر التليجرام
    self.telegramButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.telegramButton.frame = CGRectMake(40, 355, self.view.bounds.size.width - 80, 45);
    [self.telegramButton setTitle:@"✈️ الدعم عبر تليجرام" forState:UIControlStateNormal];
    self.telegramButton.backgroundColor = [UIColor colorWithRed:0.0/255.0 green:136.0/255.0 blue:204.0/255.0 alpha:1.0];
    [self.telegramButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.telegramButton.layer.cornerRadius = 10;
    [self.telegramButton addTarget:self action:@selector(openTelegram) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.telegramButton];
    
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2, 420);
    self.spinner.color = [UIColor whiteColor];
    [self.view addSubview:self.spinner];
    
    // مؤقت الخروج التلقائي بعد 15 ثانية
    self.autoExitTimer = [NSTimer scheduledTimerWithTimeInterval:15.0
                                                     target:self
                                                   selector:@selector(handleTimeoutExit)
                                                   userInfo:nil
                                                    repeats:NO];
}

- (void)openTelegram {
    NSURL *telegramURL = [NSURL URLWithString:@"https://telegram.me/LLYDL"];
    [[UIApplication sharedApplication] openURL:telegramURL options:@{} completionHandler:nil];
}

- (void)handleTimeoutExit {
    exit(0);
}

- (void)dealloc {
    [self.autoExitTimer invalidate];
}

- (void)verifyCode {
    NSString *code = [self.passcodeTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (code.length == 0) {
        self.statusLabel.text = @"يرجى إدخال كود التفعيل أولاً";
        return;
    }
    
    [self.spinner startAnimating];
    self.submitButton.enabled = NO;
    self.statusLabel.text = @"جاري الاتصال باللوحة...";
    
    NSURL *url = [NSURL URLWithString:@"https://raw.githubusercontent.com/Amaryt1/A/refs/heads/main/public/keys.json"];
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
                self.statusLabel.text = @"تعذر الاتصال بقائمة المفاتيح";
                return;
            }
            
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode != 200) {
                self.statusLabel.text = [NSString stringWithFormat:@"خطأ سيرفر رمز: %ld", (long)httpResponse.statusCode];
                return;
            }
            
            NSError *jsonError;
            id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (jsonError) {
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
                
                NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
                [[NSUserDefaults standardUserDefaults] setDouble:now forKey:@"AppActivationTimestamp"];
                [[NSUserDefaults standardUserDefaults] setDouble:durationDays forKey:@"AppActivationDurationDays"];
                [[NSUserDefaults standardUserDefaults] setObject:code forKey:@"AppActivatedCode"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                UIViewController *presentingVC = self.presentingViewController;
                [self dismissViewControllerAnimated:YES completion:^{
                    if (presentingVC) {
                        [AppLockViewController showSuccessNotificationOnVC:presentingVC];
                    }
                }];
            } else {
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
                // المزامنة الفورية للبيانات في الخلفية لتطبيق تعديلات السيرفر فوراً
                [AppLockViewController syncSubscriptionWithServer];
            }
        }
    });
}

static void __attribute__((constructor)) initializeAppLock(void) {
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
