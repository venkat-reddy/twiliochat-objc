#import "IPMessagingManager.h"
#import "ChannelManager.h"
#import "SessionManager.h"
#import "TokenRequestHandler.h"

@interface IPMessagingManager ()
@property (strong, nonatomic) TwilioIPMessagingClient *client;
@property (nonatomic, getter=isConnected) BOOL connected;
@end

static NSString * const TWCLoginViewControllerName = @"LoginViewController";
static NSString * const TWCMainViewControllerName = @"RevealViewController";

static NSString * const TWCTokenKey = @"token";

@implementation IPMessagingManager
+ (instancetype)sharedManager {
  static IPMessagingManager *sharedMyManager = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedMyManager = [[self alloc] init];
  });
  return sharedMyManager;
}

# pragma mark Present view controllers

- (void)presentRootViewController {
  if (!self.isLoggedIn) {
    [self presentViewControllerByName:TWCLoginViewControllerName];
    return;
  }
  if (!self.isConnected) {
    [self connectClientWithCompletion:^(BOOL success, NSError *error) {
      NSString *viewController = success ? TWCMainViewControllerName : TWCLoginViewControllerName;
      [self presentViewControllerByName:viewController];
    }];
    return;
  }
  [self presentViewControllerByName:TWCMainViewControllerName];
}

- (void)presentViewControllerByName:(NSString *)viewController {
  [self presentViewController:[[self storyboardWithName:@"Main"] instantiateViewControllerWithIdentifier:viewController]];
}

- (void)presentLaunchScreen {
  [self presentViewController:[[self storyboardWithName:@"LaunchScreen"] instantiateInitialViewController]];
}

- (void)presentViewController:(UIViewController *)viewController {
  UIWindow *window = [[UIApplication sharedApplication].delegate window];
  window.rootViewController = viewController;
}

- (UIStoryboard *)storyboardWithName:(NSString *)name {
  return [UIStoryboard storyboardWithName: name bundle: [NSBundle mainBundle]];
}

# pragma mark User and session management

- (BOOL)isLoggedIn {
  return [SessionManager isLoggedIn];
}

- (void)loginWithUsername:(NSString *)username
    completion:(StatusWithErrorHandler)completion {
  [SessionManager loginWithUsername:username];
  [self connectClientWithCompletion:completion];
}

- (void)logout {
  [SessionManager logout];
  self.connected = NO;
  
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [self.client shutdown];
    self.client = nil;
  });
}

# pragma mark Twilio Client

- (void)connectClientWithCompletion:(StatusWithErrorHandler)completion {
  if (self.client) {
    [self logout];
  }
  
  [self requestTokenWithCompletion:^(BOOL succeeded, NSString *token) {
    if (succeeded) {
      [self initializeClientWithToken: token];
      [self loadGeneralChatRoomWithCompletion:completion];
    }
    else {
      NSError *error = [self errorWithDescription:@"Could not get access token" code:301];
      if (completion) completion(succeeded, error);
    }
  }];
}

- (void)initializeClientWithToken:(NSString *)token {
  TwilioAccessManager *accessManager = [TwilioAccessManager accessManagerWithToken:token delegate: self];
  self.client = [TwilioIPMessagingClient ipMessagingClientWithAccessManager:accessManager delegate:nil];
}

- (void)loadGeneralChatRoomWithCompletion:(StatusWithErrorHandler)completion {
  [[ChannelManager sharedManager] joinGeneralChatRoomWithCompletion:^(BOOL succeeded) {
    if (succeeded)
    {
      self.connected = YES;
      if (completion) completion(succeeded, nil);
    }
    else {
      NSError *error = [self errorWithDescription:@"Could not join General channel" code:300];
      if (completion) completion(succeeded, error);
    }
  }];
}

- (void)requestTokenWithCompletion:(StatusWithTokenHandler)completion {
  NSString *uuid = [[UIDevice currentDevice] identifierForVendor].UUIDString;
  NSDictionary *parameters = @{@"device": uuid, @"identity": [SessionManager getUsername]};

  [TokenRequestHandler fetchTokenWithParams:parameters completion:^(NSDictionary *results, NSError *error) {
    NSString *token = [results objectForKey:TWCTokenKey];
    BOOL errorCondition = error || !token;

    if (completion) completion(!errorCondition, token);
  }];
}

- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code {
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey: description};
  NSError *error = [NSError errorWithDomain:@"app" code:code userInfo:userInfo];
  return error;
}

# pragma mark TwilioAccessManagerDelegate

- (void)accessManagerTokenExpired:(TwilioAccessManager *)accessManager {
  [self requestTokenWithCompletion:^(BOOL succeeded, NSString *token) {
    if (succeeded) {
      [accessManager updateToken:token];
    }
    else {
      NSLog(@"Error while trying to get new access token");
    }
  }];
}

- (void)accessManager:(TwilioAccessManager *)accessManager error:(NSError *)error {
  NSLog(@"Access manager error: %@", [error localizedDescription]);
}

#pragma mark Internal helpers

- (NSString *)userIdentity {
  return [SessionManager getUsername];
}

@end
