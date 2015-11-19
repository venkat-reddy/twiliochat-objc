#import <XCTest/XCTest.h>
#import <Parse/Parse.h>
#import <OCMock/OCMock.h>
#import "IPMessagingManager.h"
#import "AppDelegate.h"

@interface ViewControllerFlowManagerTests : XCTestCase
@property (strong, nonatomic) id pfUserMock;
@property (strong, nonatomic) id storyboardMock;
@property (strong, nonatomic) id windowMock;
@property (strong, nonatomic) id viewControllerMock;
@end

@implementation ViewControllerFlowManagerTests

- (void)setUp {
    [super setUp];
    
    self.pfUserMock = OCMClassMock([PFUser class]);
    id appMock = OCMClassMock([UIApplication class]);
    id appDelegateMock = OCMClassMock([AppDelegate class]);
    self.windowMock = OCMClassMock([UIWindow class]);
    self.storyboardMock = OCMClassMock([UIStoryboard class]);
    
    self.viewControllerMock = [[NSObject alloc] init];
    
    OCMStub([appMock sharedApplication]).andReturn(appMock);
    OCMStub([appMock delegate]).andReturn(appDelegateMock);
    OCMStub([appDelegateMock window]).andReturn(self.windowMock);
    OCMStub([self.storyboardMock storyboardWithName:[OCMArg any] bundle:[OCMArg any]]).andReturn(self.storyboardMock);
    OCMStub([self.storyboardMock instantiateViewControllerWithIdentifier:[OCMArg any]]).andReturn(self.viewControllerMock);
}

- (void)tearDown {
    [super tearDown];
    [self.pfUserMock stopMocking];
    [self.windowMock stopMocking];
    [self.storyboardMock stopMocking];
}

- (void)testLoggedInFlow {
    [self performFlowWithUser:self.pfUserMock expectingIdentifier:@"RevealViewController"];
}

- (void)testNotLoggedInFlow {
    [self performFlowWithUser:nil expectingIdentifier:@"LoginViewController"];
}

- (void)performFlowWithUser:(id)user expectingIdentifier:(NSString *)identifier {
    OCMStub([self.pfUserMock currentUser]).andReturn(user);
    [[IPMessagingManager sharedManager] presentRootViewController];
    OCMVerify([self.storyboardMock instantiateViewControllerWithIdentifier:identifier]);
    OCMVerify([self.windowMock setRootViewController:self.viewControllerMock]);
}

@end