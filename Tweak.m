#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface AppLockViewController : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *passcodeTextField;
@property (nonatomic, strong) UIButton *submitButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

+ (BOOL)isSubscriptionValid;
@end

@implementation AppLockViewController

+ (BOOL)isSubscriptionValid {
    NSTimeInterval activatedTime = [[NSUserDefaults standardUserDefaults] doubleForKey:@"AppActivationTimestamp"];
    double durationDays = [[NSUserDefaults standardUserDefaults] doubleForKey:@"AppActivationDurationDays"];
    
    if (activatedTime <= 0 || durationDays <= 0) return NO;
    
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval allowedDuration = durationDays * 86400.0;
    
    return (currentTime - activatedTime) < allowedDuration;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurEffectView.frame = self.view.bounds;
    blurEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:blurEffectView];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 160, self.view.bounds.size.width - 40, 40)];
    titleLabel.text = @"التطبيق محمي بكلمة مرور";
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [self.view addSubview:titleLabel];
    
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 210, self.view.bounds.size.width - 40, 30)];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.textColor = [UIColor systemRedColor];
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    [self.view addSubview:self.statusLabel];
    
    self.passcodeTextField = [[UITextField alloc] initWithFrame:CGRectMake(40, 260, self.view.bounds.size.width - 80, 50)];
    self.passcodeTextField.placeholder = @"أدخل كود التفعيل";
    self.passcodeTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.passcodeTextField.secureTextEntry = YES;
    self.passcodeTextField.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.passcodeTextField];
    
    self.submitButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.submitButton.frame = CGRectMake(40, 330, self.view.bounds.size.width - 80, 50);
    [self.submitButton setTitle:@"تحقق وتفعيل" forState:UIControlStateNormal];
    self.submitButton.backgroundColor = [UIColor systemBlueColor];
    [self.submitButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.submitButton.layer.cornerRadius = 10;
    [self.submitButton addTarget:self action:@selector(verifyCode) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.submitButton];
    
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2, 400);
    self.spinner.color = [UIColor whiteColor];
    [self.view addSubview:self.spinner];
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
    
    NSURL *url = [NSURL URLWithString:@"https://a-coral-two-10.vercel.app/api/keys"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                            cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                        timeoutInterval:10.0];
    [request setHTTPMethod:@"GET"];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            self.submitButton.enabled = YES;
            
            if (error || !data) {
                self.statusLabel.text = @"تعذر الاتصال بقائمة المفاتيح";
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
            
            NSArray *itemsArray = nil;
            if ([jsonObject isKindOfClass:[NSDictionary class]]) {
                itemsArray = jsonObject[@"details"];
            } else if ([jsonObject isKindOfClass:[NSArray class]]) {
                itemsArray = (NSArray *)jsonObject;
            }
            
            if (itemsArray) {
                for (id item in itemsArray) {
                    if ([item isKindOfClass:[NSDictionary class]]) {
                        NSString *k = item[@"code"] ?: item[@"key"] ?: item[@"passcode"];
                        if (k && [k isEqualToString:code]) {
                            isValidKey = YES;
                            double customDays = [item[@"days"] doubleValue];
                            if (customDays > 0) {
                                durationDays = customDays;
                            }
                            break;
                        }
                    } else if ([item isKindOfClass:[NSString class]] && [item isEqualToString:code]) {
                        isValidKey = YES;
                        break;
                    }
                }
            }
            
            if (isValidKey) {
                NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
                [[NSUserDefaults standardUserDefaults] setDouble:now forKey:@"AppActivationTimestamp"];
                [[NSUserDefaults standardUserDefaults] setDouble:durationDays forKey:@"AppActivationDurationDays"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                [self dismissViewControllerAnimated:YES completion:nil];
            } else {
                self.statusLabel.text = @"الكود غير صحيح أو منتهي الصلاحية";
            }
        });
    }];
    [task resume];
}

@end

static void __attribute__((constructor)) initializeAppLock(void) {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        
        if (![AppLockViewController isSubscriptionValid]) {
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
                    AppLockViewController *lockVC = [[AppLockViewController alloc] init];
                    lockVC.modalPresentationStyle = UIModalPresentationFullScreen;
                    
                    UIViewController *rootVC = window.rootViewController;
                    while (rootVC.presentedViewController) {
                        rootVC = rootVC.presentedViewController;
                    }
                    [rootVC presentViewController:lockVC animated:NO completion:nil];
                }
            });
        }
    }];
}
