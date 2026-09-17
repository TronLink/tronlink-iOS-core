#import <XCTest/XCTest.h>
@import TLCore;
#import <ProtoRPC/ProtoMethod.h>
#import <RxLibrary/GRXWriter+Immediate.h>

typedef void (^TLCoreTransactionHandler)(TransactionExtention *response, NSError *error);

// These tests never start a real network call. The spy completes locally, while
// real call objects are inspected only in their not-yet-started state.
@interface TLCoreRPCStartSpy : GRPCProtoCall
@property(nonatomic) NSUInteger startCount;
@property(nonatomic, strong) NSError *replyError;
@property(nonatomic, copy) TLCoreTransactionHandler completion;
@end

@implementation TLCoreRPCStartSpy
- (void)start {
    self.startCount += 1;
    TLCoreTransactionHandler completion = self.completion;
    self.completion = nil;
    if (completion) {
        completion(self.replyError ? nil : [TransactionExtention message], self.replyError);
    }
}
@end

@interface TLCoreWalletStartSpy : TWallet
@property(nonatomic, strong) GPBMessage *lastRequest;
@property(nonatomic, strong) TLCoreRPCStartSpy *lastCall;
@property(nonatomic, strong) NSError *nextError;
@end

@implementation TLCoreWalletStartSpy
- (GRPCProtoCall *)callWithRequest:(GPBMessage *)request handler:(TLCoreTransactionHandler)handler {
    self.lastRequest = request;
    GRPCProtoMethod *method = [[GRPCProtoMethod alloc] initWithPackage:@"protocol"
                                                            service:@"Wallet"
                                                             method:@"LocalTest"];
    self.lastCall = [[TLCoreRPCStartSpy alloc] initWithHost:@"127.0.0.1:1"
                                                  method:method
                                          requestsWriter:[GRXWriter writerWithValue:request]
                                           responseClass:[TransactionExtention class]
                                      responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
    self.lastCall.replyError = self.nextError;
    self.lastCall.completion = handler;
    return self.lastCall;
}

- (GRPCProtoCall *)RPCToClearABIContractWithRequest:(ClearABIContract *)request
                                          handler:(TLCoreTransactionHandler)handler {
    return [self callWithRequest:request handler:handler];
}

- (GRPCProtoCall *)RPCToUnDelegateResourceWithRequest:(UnDelegateResourceContract *)request
                                            handler:(TLCoreTransactionHandler)handler {
    return [self callWithRequest:request handler:handler];
}
@end

@interface GRPCServiceWrapperTests : XCTestCase
@end

@implementation GRPCServiceWrapperTests

- (void)assertUnstartedCall:(GRPCProtoCall *)call path:(NSString *)path {
    XCTAssertNotNil(call);
    XCTAssertEqual(call.state, GRXWriterStateNotStarted);
    // The pinned legacy gRPC API has no public host/path getters. Inspect its
    // stored routing data without opening a connection or changing call state.
    XCTAssertEqualObjects([call valueForKey:@"host"], @"127.0.0.1:1");
    XCTAssertEqualObjects([call valueForKey:@"path"], path);
}

- (void)testClearABIConvenienceStartsExactlyOnceAndPreservesSuccessAndErrorHandlers {
    for (NSNumber *shouldFail in @[@NO, @YES]) {
        TLCoreWalletStartSpy *wallet = [[TLCoreWalletStartSpy alloc] initWithHost:@"127.0.0.1:1"];
        ClearABIContract *request = [ClearABIContract message];
        NSError *expectedError = shouldFail.boolValue ?
            [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil] : nil;
        wallet.nextError = expectedError;
        __block NSUInteger callbacks = 0;
        [wallet clearABIContractWithRequest:request handler:^(TransactionExtention *response, NSError *error) {
            callbacks += 1;
            XCTAssertEqual(error, expectedError);
            XCTAssertEqual(response != nil, expectedError == nil);
        }];
        XCTAssertEqual(wallet.lastRequest, request);
        XCTAssertEqual(wallet.lastCall.startCount, 1u);
        XCTAssertEqual(callbacks, 1u);
    }
}

- (void)testClearABIRPCFactoryUsesProtocolMethodNameAndRequiresExplicitStart {
    TWallet *wallet = [[TWallet alloc] initWithHost:@"127.0.0.1:1"];
    GRPCProtoCall *call = [wallet RPCToClearABIContractWithRequest:[ClearABIContract message]
                                                         handler:^(TransactionExtention *response, NSError *error) {
        XCTFail(@"An unstarted call must not deliver a response");
    }];
    [self assertUnstartedCall:call path:@"/protocol.Wallet/ClearContractABI"];
}

- (void)testBothPublishedUnDelegateSelectorsCreateTheSameUnstartedRoute {
    TWallet *wallet = [[TWallet alloc] initWithHost:@"127.0.0.1:1"];
    UnDelegateResourceContract *request = [UnDelegateResourceContract message];
    TLCoreTransactionHandler handler = ^(TransactionExtention *response, NSError *error) {
        XCTFail(@"An unstarted call must not deliver a response");
    };
    GRPCProtoCall *canonical = nil;
    GRPCProtoCall *legacy = nil;
    XCTAssertNoThrow(canonical = [wallet RPCToUnDelegateResourceWithRequest:request handler:handler]);
    XCTAssertNoThrow(legacy = [wallet RPCToUnDelegateResourceWithRequestWithRequest:request handler:handler]);
    [self assertUnstartedCall:canonical path:@"/protocol.Wallet/UnDelegateResource"];
    [self assertUnstartedCall:legacy path:@"/protocol.Wallet/UnDelegateResource"];
}

- (void)testUnDelegateConvenienceStillStartsOnceAndLegacyAliasForwardsWithoutStarting {
    TLCoreWalletStartSpy *wallet = [[TLCoreWalletStartSpy alloc] initWithHost:@"127.0.0.1:1"];
    UnDelegateResourceContract *request = [UnDelegateResourceContract message];
    __block NSUInteger callbacks = 0;
    TLCoreTransactionHandler handler = ^(TransactionExtention *response, NSError *error) {
        callbacks += 1;
        XCTAssertNotNil(response);
        XCTAssertNil(error);
    };
    [wallet unDelegateResourceWithRequest:request handler:handler];
    XCTAssertEqual(wallet.lastRequest, request);
    XCTAssertEqual(wallet.lastCall.startCount, 1u);
    XCTAssertEqual(callbacks, 1u);

    GRPCProtoCall *legacy = [wallet RPCToUnDelegateResourceWithRequestWithRequest:request handler:handler];
    XCTAssertEqual(legacy, wallet.lastCall);
    XCTAssertEqual(wallet.lastRequest, request);
    XCTAssertEqual(wallet.lastCall.startCount, 0u);
    XCTAssertEqual(callbacks, 1u);
    [legacy start];
    XCTAssertEqual(wallet.lastCall.startCount, 1u);
    XCTAssertEqual(callbacks, 2u);
}

- (void)assertHistoryRoutes:(WalletExtension *)service {
    XCTAssertNotNil(service);
    AccountPaginated *request = [AccountPaginated message];
    void (^handler)(TransactionListExtention *, NSError *) = ^(TransactionListExtention *response, NSError *error) {
        XCTFail(@"An unstarted history call must not deliver a response");
    };
    [self assertUnstartedCall:[service RPCToGetTransactionsFromThis2WithRequest:request handler:handler]
                        path:@"/protocol.WalletExtension/GetTransactionsFromThis2"];
    [self assertUnstartedCall:[service RPCToGetTransactionsToThis2WithRequest:request handler:handler]
                        path:@"/protocol.WalletExtension/GetTransactionsToThis2"];
}

- (void)testWalletExtensionHostInitializerCreatesTheHistoryService {
    WalletExtension *service = nil;
    XCTAssertNoThrow(service = [[WalletExtension alloc] initWithHost:@"127.0.0.1:1"]);
    [self assertHistoryRoutes:service];
}

- (void)testWalletExtensionFactoryCreatesTheHistoryService {
    WalletExtension *service = nil;
    XCTAssertNoThrow(service = [WalletExtension serviceWithHost:@"127.0.0.1:1"]);
    [self assertHistoryRoutes:service];
}

- (void)testWalletExtensionLegacyInitializerKeepsTheFixedServiceName {
    WalletExtension *service = nil;
    XCTAssertNoThrow(service = [[WalletExtension alloc] initWithHost:@"127.0.0.1:1"
                                                       packageName:@"ignored"
                                                       serviceName:@"ignored"]);
    [self assertHistoryRoutes:service];
}
@end
