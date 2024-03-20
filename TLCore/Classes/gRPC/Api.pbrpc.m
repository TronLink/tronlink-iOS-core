#if !defined(GPB_GRPC_PROTOCOL_ONLY) || !GPB_GRPC_PROTOCOL_ONLY
#import "Api.pbrpc.h"
#import "Api_Tron.pbobjc.h"
#import <ProtoRPC/ProtoRPC.h>
#import <RxLibrary/GRXWriter+Immediate.h>

#import "Tron.pbobjc.h"
#import "Annotations.pbobjc.h"
#import "AccountContract.pbobjc.h"
#import "AssetIssueContract.pbobjc.h"
#import "BalanceContract.pbobjc.h"
#import "Common.pbobjc.h"
#import "ExchangeContract.pbobjc.h"
#import "ProposalContract.pbobjc.h"
#import "ShieldContract.pbobjc.h"
#import "SmartContract.pbobjc.h"
#import "StorageContract.pbobjc.h"
#import "VoteAssetContract.pbobjc.h"
#import "WitnessContract.pbobjc.h"

@implementation TWallet

// Designated initializer
- (instancetype)initWithHost:(NSString *)host {
  self = [super initWithHost:host
                 packageName:@"protocol"
                 serviceName:@"Wallet"];
  return self;
}

// Override superclass initializer to disallow different package and service names.
- (instancetype)initWithHost:(NSString *)host
                 packageName:(NSString *)packageName
                 serviceName:(NSString *)serviceName {
  return [self initWithHost:host];
}

#pragma mark - Class Methods

+ (instancetype)serviceWithHost:(NSString *)host {
  return [[self alloc] initWithHost:host];
}

#pragma mark - Method Implementations

#pragma mark GetAccount(Account) returns (Account)

- (void)getAccountWithRequest:(TronAccount *)request handler:(void(^)(TronAccount *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetAccountWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetAccountWithRequest:(TronAccount *)request handler:(void(^)(TronAccount *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetAccount"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TronAccount class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetAccountById(Account) returns (Account)

- (void)getAccountByIdWithRequest:(TronAccount *)request handler:(void(^)(TronAccount *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetAccountByIdWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetAccountByIdWithRequest:(TronAccount *)request handler:(void(^)(TronAccount *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetAccountById"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TronAccount class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark CreateTransaction(TransferContract) returns (Transaction)

/**
 * Please use CreateTransaction2 instead of this function.
 */
- (void)createTransactionWithRequest:(TransferContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToCreateTransactionWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Please use CreateTransaction2 instead of this function.
 */
- (GRPCProtoCall *)RPCToCreateTransactionWithRequest:(TransferContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"CreateTransaction"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TronTransaction class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark CreateTransaction2(TransferContract) returns (TransactionExtention)

/**
 * Use this function instead of CreateTransaction.
 */
- (void)createTransaction2WithRequest:(TransferContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToCreateTransaction2WithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Use this function instead of CreateTransaction.
 */
- (GRPCProtoCall *)RPCToCreateTransaction2WithRequest:(TransferContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"CreateTransaction2"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark BroadcastTransaction(Transaction) returns (Return)

- (void)broadcastTransactionWithRequest:(TronTransaction *)request handler:(void(^)(Return *_Nullable response, NSError *_Nullable error))handler{
    GRPCProtoCall *rpcCall = [self RPCToBroadcastTransactionWithRequest:request handler:handler];
    rpcCall.timeout = 8;
    [rpcCall start];
//  [[self RPCToBroadcastTransactionWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToBroadcastTransactionWithRequest:(TronTransaction *)request handler:(void(^)(Return *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"BroadcastTransaction"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[Return class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark UpdateAccount(AccountUpdateContract) returns (Transaction)

/**
 * Please use UpdateAccount2 instead of this function.
 */
- (void)updateAccountWithRequest:(AccountUpdateContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToUpdateAccountWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Please use UpdateAccount2 instead of this function.
 */
- (GRPCProtoCall *)RPCToUpdateAccountWithRequest:(AccountUpdateContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"UpdateAccount"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TronTransaction class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark SetAccountId(SetAccountIdContract) returns (Transaction)

- (void)setAccountIdWithRequest:(SetAccountIdContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToSetAccountIdWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToSetAccountIdWithRequest:(SetAccountIdContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"SetAccountId"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TronTransaction class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark UpdateAccount2(AccountUpdateContract) returns (TransactionExtention)

/**
 * Use this function instead of UpdateAccount.
 */
- (void)updateAccount2WithRequest:(AccountUpdateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToUpdateAccount2WithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Use this function instead of UpdateAccount.
 */
- (GRPCProtoCall *)RPCToUpdateAccount2WithRequest:(AccountUpdateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"UpdateAccount2"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark VoteWitnessAccount(VoteWitnessContract) returns (Transaction)

/**
 * Please use VoteWitnessAccount2 instead of this function.
 */
- (void)voteWitnessAccountWithRequest:(VoteWitnessContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToVoteWitnessAccountWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Please use VoteWitnessAccount2 instead of this function.
 */
- (GRPCProtoCall *)RPCToVoteWitnessAccountWithRequest:(VoteWitnessContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"VoteWitnessAccount"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TronTransaction class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark UpdateSetting(UpdateSettingContract) returns (TransactionExtention)

/**
 * modify the consume_user_resource_percent
 */
- (void)updateSettingWithRequest:(UpdateSettingContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToUpdateSettingWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * modify the consume_user_resource_percent
 */
- (GRPCProtoCall *)RPCToUpdateSettingWithRequest:(UpdateSettingContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"UpdateSetting"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark VoteWitnessAccount2(VoteWitnessContract) returns (TransactionExtention)

/**
 * Use this function instead of VoteWitnessAccount.
 */
- (void)voteWitnessAccount2WithRequest:(VoteWitnessContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToVoteWitnessAccount2WithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Use this function instead of VoteWitnessAccount.
 */
- (GRPCProtoCall *)RPCToVoteWitnessAccount2WithRequest:(VoteWitnessContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"VoteWitnessAccount2"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark CreateAssetIssue(AssetIssueContract) returns (Transaction)

/**
 * Please use CreateAssetIssue2 instead of this function.
 */
- (void)createAssetIssueWithRequest:(AssetIssueContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToCreateAssetIssueWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Please use CreateAssetIssue2 instead of this function.
 */
- (GRPCProtoCall *)RPCToCreateAssetIssueWithRequest:(AssetIssueContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"CreateAssetIssue"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TronTransaction class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark CreateAssetIssue2(AssetIssueContract) returns (TransactionExtention)

/**
 * Use this function instead of CreateAssetIssue.
 */
- (void)createAssetIssue2WithRequest:(AssetIssueContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToCreateAssetIssue2WithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Use this function instead of CreateAssetIssue.
 */
- (GRPCProtoCall *)RPCToCreateAssetIssue2WithRequest:(AssetIssueContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"CreateAssetIssue2"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark UpdateWitness(WitnessUpdateContract) returns (Transaction)

/**
 * Please use UpdateWitness2 instead of this function.
 */
- (void)updateWitnessWithRequest:(WitnessUpdateContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToUpdateWitnessWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Please use UpdateWitness2 instead of this function.
 */
- (GRPCProtoCall *)RPCToUpdateWitnessWithRequest:(WitnessUpdateContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"UpdateWitness"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TronTransaction class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark UpdateWitness2(WitnessUpdateContract) returns (TransactionExtention)

/**
 * Use this function instead of UpdateWitness.
 */
- (void)updateWitness2WithRequest:(WitnessUpdateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToUpdateWitness2WithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Use this function instead of UpdateWitness.
 */
- (GRPCProtoCall *)RPCToUpdateWitness2WithRequest:(WitnessUpdateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"UpdateWitness2"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark CreateAccount(AccountCreateContract) returns (Transaction)

/**
 * Please use CreateAccount2 instead of this function.
 */
- (void)createAccountWithRequest:(AccountCreateContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToCreateAccountWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Please use CreateAccount2 instead of this function.
 */
- (GRPCProtoCall *)RPCToCreateAccountWithRequest:(AccountCreateContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"CreateAccount"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TronTransaction class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark CreateAccount2(AccountCreateContract) returns (TransactionExtention)

/**
 * Use this function instead of CreateAccount.
 */
- (void)createAccount2WithRequest:(AccountCreateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToCreateAccount2WithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Use this function instead of CreateAccount.
 */
- (GRPCProtoCall *)RPCToCreateAccount2WithRequest:(AccountCreateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"CreateAccount2"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark CreateWitness(WitnessCreateContract) returns (Transaction)

/**
 * Please use CreateWitness2 instead of this function.
 */
- (void)createWitnessWithRequest:(WitnessCreateContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToCreateWitnessWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Please use CreateWitness2 instead of this function.
 */
- (GRPCProtoCall *)RPCToCreateWitnessWithRequest:(WitnessCreateContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"CreateWitness"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TronTransaction class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark CreateWitness2(WitnessCreateContract) returns (TransactionExtention)

/**
 * Use this function instead of CreateWitness.
 */
- (void)createWitness2WithRequest:(WitnessCreateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToCreateWitness2WithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Use this function instead of CreateWitness.
 */
- (GRPCProtoCall *)RPCToCreateWitness2WithRequest:(WitnessCreateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"CreateWitness2"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark TransferAsset(TransferAssetContract) returns (Transaction)

/**
 * Please use TransferAsset2 instead of this function.
 */
- (void)transferAssetWithRequest:(TransferAssetContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToTransferAssetWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Please use TransferAsset2 instead of this function.
 */
- (GRPCProtoCall *)RPCToTransferAssetWithRequest:(TransferAssetContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"TransferAsset"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TronTransaction class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark TransferAsset2(TransferAssetContract) returns (TransactionExtention)

/**
 * Use this function instead of TransferAsset.
 */
- (void)transferAsset2WithRequest:(TransferAssetContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToTransferAsset2WithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Use this function instead of TransferAsset.
 */
- (GRPCProtoCall *)RPCToTransferAsset2WithRequest:(TransferAssetContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"TransferAsset2"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark ParticipateAssetIssue(ParticipateAssetIssueContract) returns (Transaction)

/**
 * Please use ParticipateAssetIssue2 instead of this function.
 */
- (void)participateAssetIssueWithRequest:(ParticipateAssetIssueContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToParticipateAssetIssueWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Please use ParticipateAssetIssue2 instead of this function.
 */
- (GRPCProtoCall *)RPCToParticipateAssetIssueWithRequest:(ParticipateAssetIssueContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"ParticipateAssetIssue"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TronTransaction class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark ParticipateAssetIssue2(ParticipateAssetIssueContract) returns (TransactionExtention)

/**
 * Use this function instead of ParticipateAssetIssue.
 */
- (void)participateAssetIssue2WithRequest:(ParticipateAssetIssueContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToParticipateAssetIssue2WithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Use this function instead of ParticipateAssetIssue.
 */
- (GRPCProtoCall *)RPCToParticipateAssetIssue2WithRequest:(ParticipateAssetIssueContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"ParticipateAssetIssue2"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark FreezeBalance(FreezeBalanceContract) returns (Transaction)

/**
 * Please use FreezeBalance2 instead of this function.
 */
- (void)freezeBalanceWithRequest:(FreezeBalanceContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToFreezeBalanceWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Please use FreezeBalance2 instead of this function.
 */
- (GRPCProtoCall *)RPCToFreezeBalanceWithRequest:(FreezeBalanceContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"FreezeBalance"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TronTransaction class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark FreezeBalance2(FreezeBalanceContract) returns (TransactionExtention)

/**
 * Use this function instead of FreezeBalance.
 */
- (void)freezeBalance2WithRequest:(FreezeBalanceContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToFreezeBalance2WithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Use this function instead of FreezeBalance.
 */
- (GRPCProtoCall *)RPCToFreezeBalance2WithRequest:(FreezeBalanceContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"FreezeBalance2"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark FreezeBalanceV2(FreezeBalanceV2Contract) returns (TransactionExtention)

- (void)freezeBalanceV2WithRequest:(FreezeBalanceV2Contract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
    [[self RPCToFreezeBalanceV2WithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToFreezeBalanceV2WithRequest:(FreezeBalanceV2Contract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
    return [self RPCToMethod:@"FreezeBalanceV2"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[TransactionExtention class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark UnfreezeBalanceV2(UnfreezeBalanceV2Contract) returns (TransactionExtention)

- (void)unfreezeBalanceV2WithRequest:(UnfreezeBalanceV2Contract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
    [[self RPCToUnfreezeBalanceV2WithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToUnfreezeBalanceV2WithRequest:(UnfreezeBalanceV2Contract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
    return [self RPCToMethod:@"UnfreezeBalanceV2"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[TransactionExtention class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark WithdrawExpireUnfreeze(WithdrawExpireUnfreezeContract) returns (TransactionExtention)

- (void)withdrawExpireUnfreezeWithRequest:(WithdrawExpireUnfreezeContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
    [[self RPCToWithdrawExpireUnfreezeWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToWithdrawExpireUnfreezeWithRequest:(WithdrawExpireUnfreezeContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
    return [self RPCToMethod:@"WithdrawExpireUnfreeze"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[TransactionExtention class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark DelegateResource(DelegateResourceContract) returns (TransactionExtention)

- (void)delegateResourceWithRequest:(DelegateResourceContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
    [[self RPCToDelegateResourceWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToDelegateResourceWithRequest:(DelegateResourceContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
    return [self RPCToMethod:@"DelegateResource"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[TransactionExtention class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark UnDelegateResource(UnDelegateResourceContract) returns (TransactionExtention)

- (void)unDelegateResourceWithRequest:(UnDelegateResourceContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
    [[self RPCToUnDelegateResourceWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToUnDelegateResourceWithRequest:(UnDelegateResourceContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
    return [self RPCToMethod:@"UnDelegateResource"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[TransactionExtention class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark CanDelegatedMaxSize(CanDelegatedMaxSizeRequestMessage) returns (CanDelegatedMaxSizeResponseMessage)

- (void)getCanDelegatedMaxSizeWithRequest:(CanDelegatedMaxSizeRequestMessage *)request handler:(void(^)(CanDelegatedMaxSizeResponseMessage *_Nullable response, NSError *_Nullable error))handler{
    [[self RPCToGetCanDelegatedMaxSizeWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToGetCanDelegatedMaxSizeWithRequest:(CanDelegatedMaxSizeRequestMessage *)request handler:(void(^)(CanDelegatedMaxSizeResponseMessage *_Nullable response, NSError *_Nullable error))handler{
    return [self RPCToMethod:@"GetCanDelegatedMaxSize"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[CanDelegatedMaxSizeResponseMessage class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark CanWithdrawUnfreezeAmount(CanWithdrawUnfreezeAmountRequestMessage) returns (CanWithdrawUnfreezeAmountResponseMessage)

- (void)getCanWithdrawUnfreezeAmountWithRequest:(CanWithdrawUnfreezeAmountRequestMessage *)request handler:(void(^)(CanWithdrawUnfreezeAmountResponseMessage *_Nullable response, NSError *_Nullable error))handler{
    [[self RPCToCanWithdrawUnfreezeAmountRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToCanWithdrawUnfreezeAmountRequest:(CanWithdrawUnfreezeAmountRequestMessage *)request handler:(void(^)(CanWithdrawUnfreezeAmountResponseMessage *_Nullable response, NSError *_Nullable error))handler{
    return [self RPCToMethod:@"GetCanWithdrawUnfreezeAmount"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[CanWithdrawUnfreezeAmountResponseMessage class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark GetAvailableUnfreezeCount(GetAvailableUnfreezeCountRequestMessage) returns (GetAvailableUnfreezeCountResponseMessage)

- (void)GetAvailableUnfreezeCountWithRequest:(GetAvailableUnfreezeCountRequestMessage *)request handler:(void(^)(GetAvailableUnfreezeCountResponseMessage *_Nullable response, NSError *_Nullable error))handler{
    [[self RPCToGetAvailableUnfreezeCountRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToGetAvailableUnfreezeCountRequest:(GetAvailableUnfreezeCountRequestMessage *)request handler:(void(^)(GetAvailableUnfreezeCountResponseMessage *_Nullable response, NSError *_Nullable error))handler{
    return [self RPCToMethod:@"GetAvailableUnfreezeCount"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[GetAvailableUnfreezeCountResponseMessage class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark UnfreezeBalance(UnfreezeBalanceContract) returns (Transaction)

/**
 * Please use UnfreezeBalance2 instead of this function.
 */
- (void)unfreezeBalanceWithRequest:(UnfreezeBalanceContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToUnfreezeBalanceWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Please use UnfreezeBalance2 instead of this function.
 */
- (GRPCProtoCall *)RPCToUnfreezeBalanceWithRequest:(UnfreezeBalanceContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"UnfreezeBalance"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TronTransaction class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark UnfreezeBalance2(UnfreezeBalanceContract) returns (TransactionExtention)

/**
 * Use this function instead of UnfreezeBalance.
 */
- (void)unfreezeBalance2WithRequest:(UnfreezeBalanceContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToUnfreezeBalance2WithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Use this function instead of UnfreezeBalance.
 */
- (GRPCProtoCall *)RPCToUnfreezeBalance2WithRequest:(UnfreezeBalanceContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"UnfreezeBalance2"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark UnfreezeAsset(UnfreezeAssetContract) returns (Transaction)

/**
 * Please use UnfreezeAsset2 instead of this function.
 */
- (void)unfreezeAssetWithRequest:(UnfreezeAssetContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToUnfreezeAssetWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Please use UnfreezeAsset2 instead of this function.
 */
- (GRPCProtoCall *)RPCToUnfreezeAssetWithRequest:(UnfreezeAssetContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"UnfreezeAsset"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TronTransaction class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark UnfreezeAsset2(UnfreezeAssetContract) returns (TransactionExtention)

/**
 * Use this function instead of UnfreezeAsset.
 */
- (void)unfreezeAsset2WithRequest:(UnfreezeAssetContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToUnfreezeAsset2WithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Use this function instead of UnfreezeAsset.
 */
- (GRPCProtoCall *)RPCToUnfreezeAsset2WithRequest:(UnfreezeAssetContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"UnfreezeAsset2"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark WithdrawBalance(WithdrawBalanceContract) returns (Transaction)

/**
 * Please use WithdrawBalance2 instead of this function.
 */
- (void)withdrawBalanceWithRequest:(WithdrawBalanceContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToWithdrawBalanceWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Please use WithdrawBalance2 instead of this function.
 */
- (GRPCProtoCall *)RPCToWithdrawBalanceWithRequest:(WithdrawBalanceContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"WithdrawBalance"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TronTransaction class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark WithdrawBalance2(WithdrawBalanceContract) returns (TransactionExtention)

/**
 * Use this function instead of WithdrawBalance.
 */
- (void)withdrawBalance2WithRequest:(WithdrawBalanceContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToWithdrawBalance2WithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Use this function instead of WithdrawBalance.
 */
- (GRPCProtoCall *)RPCToWithdrawBalance2WithRequest:(WithdrawBalanceContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"WithdrawBalance2"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark UpdateAsset(UpdateAssetContract) returns (Transaction)

/**
 * Please use UpdateAsset2 instead of this function.
 */
- (void)updateAssetWithRequest:(UpdateAssetContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToUpdateAssetWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Please use UpdateAsset2 instead of this function.
 */
- (GRPCProtoCall *)RPCToUpdateAssetWithRequest:(UpdateAssetContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"UpdateAsset"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TronTransaction class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark UpdateAsset2(UpdateAssetContract) returns (TransactionExtention)

/**
 * Use this function instead of UpdateAsset.
 */
- (void)updateAsset2WithRequest:(UpdateAssetContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToUpdateAsset2WithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Use this function instead of UpdateAsset.
 */
- (GRPCProtoCall *)RPCToUpdateAsset2WithRequest:(UpdateAssetContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"UpdateAsset2"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark ProposalCreate(ProposalCreateContract) returns (TransactionExtention)

- (void)proposalCreateWithRequest:(ProposalCreateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToProposalCreateWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToProposalCreateWithRequest:(ProposalCreateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"ProposalCreate"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark ProposalApprove(ProposalApproveContract) returns (TransactionExtention)

- (void)proposalApproveWithRequest:(ProposalApproveContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToProposalApproveWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToProposalApproveWithRequest:(ProposalApproveContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"ProposalApprove"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark ProposalDelete(ProposalDeleteContract) returns (TransactionExtention)

- (void)proposalDeleteWithRequest:(ProposalDeleteContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToProposalDeleteWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToProposalDeleteWithRequest:(ProposalDeleteContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"ProposalDelete"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark BuyStorage(BuyStorageContract) returns (TransactionExtention)

- (void)buyStorageWithRequest:(BuyStorageContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToBuyStorageWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToBuyStorageWithRequest:(BuyStorageContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"BuyStorage"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark BuyStorageBytes(BuyStorageBytesContract) returns (TransactionExtention)

- (void)buyStorageBytesWithRequest:(BuyStorageBytesContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToBuyStorageBytesWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToBuyStorageBytesWithRequest:(BuyStorageBytesContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"BuyStorageBytes"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark SellStorage(SellStorageContract) returns (TransactionExtention)

- (void)sellStorageWithRequest:(SellStorageContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToSellStorageWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToSellStorageWithRequest:(SellStorageContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"SellStorage"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark ExchangeCreate(ExchangeCreateContract) returns (TransactionExtention)

- (void)exchangeCreateWithRequest:(ExchangeCreateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToExchangeCreateWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToExchangeCreateWithRequest:(ExchangeCreateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"ExchangeCreate"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark ExchangeInject(ExchangeInjectContract) returns (TransactionExtention)

- (void)exchangeInjectWithRequest:(ExchangeInjectContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToExchangeInjectWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToExchangeInjectWithRequest:(ExchangeInjectContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"ExchangeInject"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark ExchangeWithdraw(ExchangeWithdrawContract) returns (TransactionExtention)

- (void)exchangeWithdrawWithRequest:(ExchangeWithdrawContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToExchangeWithdrawWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToExchangeWithdrawWithRequest:(ExchangeWithdrawContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"ExchangeWithdraw"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark ExchangeTransaction(ExchangeTransactionContract) returns (TransactionExtention)

- (void)exchangeTransactionWithRequest:(ExchangeTransactionContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToExchangeTransactionWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToExchangeTransactionWithRequest:(ExchangeTransactionContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"ExchangeTransaction"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark ListNodes(EmptyMessage) returns (NodeList)

- (void)listNodesWithRequest:(EmptyMessage *)request handler:(void(^)(NodeList *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToListNodesWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToListNodesWithRequest:(EmptyMessage *)request handler:(void(^)(NodeList *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"ListNodes"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[NodeList class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetAssetIssueByAccount(Account) returns (AssetIssueList)

- (void)getAssetIssueByAccountWithRequest:(TronAccount *)request handler:(void(^)(AssetIssueList *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetAssetIssueByAccountWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetAssetIssueByAccountWithRequest:(TronAccount *)request handler:(void(^)(AssetIssueList *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetAssetIssueByAccount"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[AssetIssueList class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetAccountNet(Account) returns (AccountNetMessage)

- (void)getAccountNetWithRequest:(TronAccount *)request handler:(void(^)(AccountNetMessage *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetAccountNetWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetAccountNetWithRequest:(TronAccount *)request handler:(void(^)(AccountNetMessage *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetAccountNet"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[AccountNetMessage class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetAccountResource(Account) returns (AccountResourceMessage)

- (void)getAccountResourceWithRequest:(TronAccount *)request handler:(void(^)(AccountResourceMessage *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetAccountResourceWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetAccountResourceWithRequest:(TronAccount *)request handler:(void(^)(AccountResourceMessage *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetAccountResource"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[AccountResourceMessage class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetAssetIssueByName(BytesMessage) returns (AssetIssueContract)

- (void)getAssetIssueByNameWithRequest:(BytesMessage *)request handler:(void(^)(AssetIssueContract *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetAssetIssueByNameWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetAssetIssueByNameWithRequest:(BytesMessage *)request handler:(void(^)(AssetIssueContract *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetAssetIssueByName"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[AssetIssueContract class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark CancelAllUnfreezeV2(CancelAllUnfreezeV2Contract) returns (TransactionExtention)

- (void)cancelAllUnfreezeV2WithRequest:(CancelAllUnfreezeV2Contract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToCancelAllUnfreezeV2WithRequestWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToCancelAllUnfreezeV2WithRequestWithRequest:(CancelAllUnfreezeV2Contract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"CancelAllUnfreezeV2"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[TransactionExtention class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark GetNowBlock(EmptyMessage) returns (Block)

/**
 * Please use GetNowBlock2 instead of this function.
 */
- (void)getNowBlockWithRequest:(EmptyMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetNowBlockWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Please use GetNowBlock2 instead of this function.
 */
- (GRPCProtoCall *)RPCToGetNowBlockWithRequest:(EmptyMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetNowBlock"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[Block class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetNowBlock2(EmptyMessage) returns (BlockExtention)

/**
 * Use this function instead of GetNowBlock.
 */
- (void)getNowBlock2WithRequest:(EmptyMessage *)request handler:(void(^)(BlockExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetNowBlock2WithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Use this function instead of GetNowBlock.
 */
- (GRPCProtoCall *)RPCToGetNowBlock2WithRequest:(EmptyMessage *)request handler:(void(^)(BlockExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetNowBlock2"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[BlockExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetBlockByNum(NumberMessage) returns (Block)

/**
 * Please use GetBlockByNum2 instead of this function.
 */
- (void)getBlockByNumWithRequest:(NumberMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetBlockByNumWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Please use GetBlockByNum2 instead of this function.
 */
- (GRPCProtoCall *)RPCToGetBlockByNumWithRequest:(NumberMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetBlockByNum"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[Block class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetBlockByNum2(NumberMessage) returns (BlockExtention)

/**
 * Use this function instead of GetBlockByNum.
 */
- (void)getBlockByNum2WithRequest:(NumberMessage *)request handler:(void(^)(BlockExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetBlockByNum2WithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Use this function instead of GetBlockByNum.
 */
- (GRPCProtoCall *)RPCToGetBlockByNum2WithRequest:(NumberMessage *)request handler:(void(^)(BlockExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetBlockByNum2"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[BlockExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetTransactionCountByBlockNum(NumberMessage) returns (NumberMessage)

- (void)getTransactionCountByBlockNumWithRequest:(NumberMessage *)request handler:(void(^)(NumberMessage *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetTransactionCountByBlockNumWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetTransactionCountByBlockNumWithRequest:(NumberMessage *)request handler:(void(^)(NumberMessage *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetTransactionCountByBlockNum"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[NumberMessage class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetBlockById(BytesMessage) returns (Block)

- (void)getBlockByIdWithRequest:(BytesMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetBlockByIdWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetBlockByIdWithRequest:(BytesMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetBlockById"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[Block class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetBlockByLimitNext(BlockLimit) returns (BlockList)

/**
 * Please use GetBlockByLimitNext2 instead of this function.
 */
- (void)getBlockByLimitNextWithRequest:(BlockLimit *)request handler:(void(^)(BlockList *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetBlockByLimitNextWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Please use GetBlockByLimitNext2 instead of this function.
 */
- (GRPCProtoCall *)RPCToGetBlockByLimitNextWithRequest:(BlockLimit *)request handler:(void(^)(BlockList *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetBlockByLimitNext"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[BlockList class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetBlockByLimitNext2(BlockLimit) returns (BlockListExtention)

/**
 * Use this function instead of GetBlockByLimitNext.
 */
- (void)getBlockByLimitNext2WithRequest:(BlockLimit *)request handler:(void(^)(BlockListExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetBlockByLimitNext2WithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Use this function instead of GetBlockByLimitNext.
 */
- (GRPCProtoCall *)RPCToGetBlockByLimitNext2WithRequest:(BlockLimit *)request handler:(void(^)(BlockListExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetBlockByLimitNext2"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[BlockListExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetBlockByLatestNum(NumberMessage) returns (BlockList)

/**
 * Please use GetBlockByLatestNum2 instead of this function.
 */
- (void)getBlockByLatestNumWithRequest:(NumberMessage *)request handler:(void(^)(BlockList *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetBlockByLatestNumWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Please use GetBlockByLatestNum2 instead of this function.
 */
- (GRPCProtoCall *)RPCToGetBlockByLatestNumWithRequest:(NumberMessage *)request handler:(void(^)(BlockList *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetBlockByLatestNum"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[BlockList class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetBlockByLatestNum2(NumberMessage) returns (BlockListExtention)

/**
 * Use this function instead of GetBlockByLatestNum.
 */
- (void)getBlockByLatestNum2WithRequest:(NumberMessage *)request handler:(void(^)(BlockListExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetBlockByLatestNum2WithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Use this function instead of GetBlockByLatestNum.
 */
- (GRPCProtoCall *)RPCToGetBlockByLatestNum2WithRequest:(NumberMessage *)request handler:(void(^)(BlockListExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetBlockByLatestNum2"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[BlockListExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetTransactionById(BytesMessage) returns (Transaction)

- (void)getTransactionByIdWithRequest:(BytesMessage *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetTransactionByIdWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetTransactionByIdWithRequest:(BytesMessage *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetTransactionById"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TronTransaction class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark DeployContract(CreateSmartContract) returns (TransactionExtention)

- (void)deployContractWithRequest:(CreateSmartContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToDeployContractWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToDeployContractWithRequest:(CreateSmartContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"DeployContract"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark ClearABIContract(ClearABIContract) returns (TransactionExtention)

- (void)clearABIContractWithRequest:(ClearABIContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler {
    [self RPCToClearABIContractWithRequest:request handler:handler];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToClearABIContractWithRequest:(ClearABIContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"ClearABIContract"
        requestsWriter:[GRXWriter writerWithValue:request]
         responseClass:[TransactionExtention class]
    responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark GetContract(BytesMessage) returns (SmartContract)

- (void)getContractWithRequest:(BytesMessage *)request handler:(void(^)(SmartContract *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetContractWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetContractWithRequest:(BytesMessage *)request handler:(void(^)(SmartContract *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetContract"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[SmartContract class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark TriggerContract(TriggerSmartContract) returns (TransactionExtention)

- (void)triggerContractWithRequest:(TriggerSmartContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToTriggerContractWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToTriggerContractWithRequest:(TriggerSmartContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"TriggerContract"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark TriggerConstantContract(TriggerSmartContract) returns (TransactionExtention)

- (void)triggerConstantContractWithRequest:(TriggerSmartContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToTriggerConstantContractWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToTriggerConstantContractWithRequest:(TriggerSmartContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"TriggerConstantContract"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}


#pragma mark ListWitnesses(EmptyMessage) returns (WitnessList)

- (void)listWitnessesWithRequest:(EmptyMessage *)request handler:(void(^)(WitnessList *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToListWitnessesWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToListWitnessesWithRequest:(EmptyMessage *)request handler:(void(^)(WitnessList *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"ListWitnesses"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[WitnessList class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark ListProposals(EmptyMessage) returns (ProposalList)

- (void)listProposalsWithRequest:(EmptyMessage *)request handler:(void(^)(ProposalList *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToListProposalsWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToListProposalsWithRequest:(EmptyMessage *)request handler:(void(^)(ProposalList *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"ListProposals"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[ProposalList class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetProposalById(BytesMessage) returns (Proposal)

- (void)getProposalByIdWithRequest:(BytesMessage *)request handler:(void(^)(Proposal *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetProposalByIdWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetProposalByIdWithRequest:(BytesMessage *)request handler:(void(^)(Proposal *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetProposalById"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[Proposal class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark ListExchanges(EmptyMessage) returns (ExchangeList)

- (void)listExchangesWithRequest:(EmptyMessage *)request handler:(void(^)(ExchangeList *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToListExchangesWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToListExchangesWithRequest:(EmptyMessage *)request handler:(void(^)(ExchangeList *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"ListExchanges"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[ExchangeList class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetExchangeById(BytesMessage) returns (Exchange)

- (void)getExchangeByIdWithRequest:(BytesMessage *)request handler:(void(^)(Exchange *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetExchangeByIdWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetExchangeByIdWithRequest:(BytesMessage *)request handler:(void(^)(Exchange *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetExchangeById"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[Exchange class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetChainParameters(EmptyMessage) returns (ChainParameters)

- (void)getChainParametersWithRequest:(EmptyMessage *)request handler:(void(^)(ChainParameters *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetChainParametersWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetChainParametersWithRequest:(EmptyMessage *)request handler:(void(^)(ChainParameters *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetChainParameters"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[ChainParameters class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetAssetIssueList(EmptyMessage) returns (AssetIssueList)

- (void)getAssetIssueListWithRequest:(EmptyMessage *)request handler:(void(^)(AssetIssueList *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetAssetIssueListWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetAssetIssueListWithRequest:(EmptyMessage *)request handler:(void(^)(AssetIssueList *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetAssetIssueList"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[AssetIssueList class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetPaginatedAssetIssueList(PaginatedMessage) returns (AssetIssueList)

- (void)getPaginatedAssetIssueListWithRequest:(PaginatedMessage *)request handler:(void(^)(AssetIssueList *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetPaginatedAssetIssueListWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetPaginatedAssetIssueListWithRequest:(PaginatedMessage *)request handler:(void(^)(AssetIssueList *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetPaginatedAssetIssueList"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[AssetIssueList class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark TotalTransaction(EmptyMessage) returns (NumberMessage)

- (void)totalTransactionWithRequest:(EmptyMessage *)request handler:(void(^)(NumberMessage *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToTotalTransactionWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToTotalTransactionWithRequest:(EmptyMessage *)request handler:(void(^)(NumberMessage *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"TotalTransaction"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[NumberMessage class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetNextMaintenanceTime(EmptyMessage) returns (NumberMessage)

- (void)getNextMaintenanceTimeWithRequest:(EmptyMessage *)request handler:(void(^)(NumberMessage *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetNextMaintenanceTimeWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetNextMaintenanceTimeWithRequest:(EmptyMessage *)request handler:(void(^)(NumberMessage *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetNextMaintenanceTime"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[NumberMessage class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark CreateAddress(BytesMessage) returns (BytesMessage)

/**
 * Warning: do not invoke this interface provided by others.
 */
- (void)createAddressWithRequest:(BytesMessage *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToCreateAddressWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Warning: do not invoke this interface provided by others.
 */
- (GRPCProtoCall *)RPCToCreateAddressWithRequest:(BytesMessage *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"CreateAddress"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[BytesMessage class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark GetTransactionInfoById(BytesMessage) returns (TransactionInfo)

- (void)getTransactionInfoByIdWithRequest:(BytesMessage *)request handler:(void(^)(TransactionInfo *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetTransactionInfoByIdWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetTransactionInfoByIdWithRequest:(BytesMessage *)request handler:(void(^)(TransactionInfo *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetTransactionInfoById"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionInfo class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark GetDelegatedResourceAccountIndex (BytesMessage) returns (DelegatedResourceAccountIndex)

- (void)getDelegatedResourceAccountWithRequest:(BytesMessage *)request handler:(void(^)(DelegatedResourceAccountIndex *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToGetDelegatedResourceAccountWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToGetDelegatedResourceAccountWithRequest:(BytesMessage *)request handler:(void (^)(DelegatedResourceAccountIndex * _Nullable, NSError * _Nullable))handler {
    return [self RPCToMethod:@"GetDelegatedResourceAccountIndex"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[DelegatedResourceAccountIndex class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark GetDelegatedResource (DelegatedResourceMessage) returns (DelegatedResourceList)

- (void)getDelegatedResourceWithRequest:(DelegatedResourceMessage *)request handler:(void (^)(DelegatedResourceList * _Nullable, NSError * _Nullable))handler {
    [[self RPCToGetDelegatedResourceWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToGetDelegatedResourceWithRequest:(DelegatedResourceMessage *)request handler:(void(^)(DelegatedResourceList *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"GetDelegatedResource"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[DelegatedResourceList class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark GetDelegatedResourceV2(Account) returns (DelegatedResourceAccountIndex)

- (void)getDelegatedResourceV2AccountWithRequest:(BytesMessage *)request handler:(void(^)(DelegatedResourceAccountIndex *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToGetDelegatedResourceV2AccountWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToGetDelegatedResourceV2AccountWithRequest:(BytesMessage *)request handler:(void(^)(DelegatedResourceAccountIndex *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"GetDelegatedResourceAccountIndexV2"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[DelegatedResourceAccountIndex class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark GetDelegatedResourceV2(Account) returns (DelegatedResourceList)

- (void)getDelegatedResourceV2WithRequest:(DelegatedResourceMessage *)request handler:(void(^)(DelegatedResourceList *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToGetDelegatedResourceV2WithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToGetDelegatedResourceV2WithRequest:(DelegatedResourceMessage *)request handler:(void(^)(DelegatedResourceList *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"GetDelegatedResourceV2"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[DelegatedResourceList class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark AccountPermissionUpdate(AccountPermissionUpdateContract) returns (TransactionExtention)

- (void)accountPermissionUpdateWithRequest:(AccountPermissionUpdateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToAccountPermissionUpdateWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToAccountPermissionUpdateWithRequest:(AccountPermissionUpdateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"AccountPermissionUpdate"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[TransactionExtention class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark GetTransactionApprovedList(Transaction) returns (TransactionApprovedList)

- (void)getTransactionApprovedListWithRequest:(TronTransaction *)request handler:(void(^)(TransactionApprovedList *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToGetTransactionApprovedListWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToGetTransactionApprovedListWithRequest:(TronTransaction *)request handler:(void(^)(TransactionApprovedList *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"GetTransactionApprovedList"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[TransactionApprovedList class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark GetTransactionSignWeight (Transaction) returns (TransactionSignWeight)

- (void)getTransactionSignWeightWithRequest:(TronTransaction *)request handler:(void(^)(TransactionSignWeight *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToGetTransactionSignWeightWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToGetTransactionSignWeightWithRequest:(TronTransaction *)request handler:(void(^)(TransactionSignWeight *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"GetTransactionSignWeight"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[TransactionSignWeight class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark GetRewardInfo (BytesMessage) returns (NumberMessage)

- (void)getRewardInfoWithRequest:(BytesMessage *)request handler:(void(^)(NumberMessage *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToGetRewardInfoWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToGetRewardInfoWithRequest:(BytesMessage *)request handler:(void(^)(NumberMessage *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"GetRewardInfo"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[NumberMessage class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark GetBrokerageInfo (BytesMessage) returns (NumberMessage)
- (void)getBrokerageInfoWithRequest:(BytesMessage *)request handler:(void(^)(NumberMessage *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToGetBrokerageInfoWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToGetBrokerageInfoWithRequest:(BytesMessage *)request handler:(void(^)(NumberMessage *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"GetBrokerageInfo"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[NumberMessage class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark UpdateBrokerage (UpdateBrokerageContract) returns (TransactionExtention)
- (void)updateBrokerageWithRequest:(UpdateBrokerageContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToUpdateBrokerageWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToUpdateBrokerageWithRequest:(UpdateBrokerageContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"UpdateBrokerageContract"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[TransactionExtention class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark CreateShieldedTransaction (PrivateParameters) returns (TransactionExtention)
- (void)createShieldedTransactionWithRequest:(PrivateParameters *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToCreateShieldedTransactionWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToCreateShieldedTransactionWithRequest:(PrivateParameters *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"CreateShieldedTransaction"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[TransactionExtention class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark GetMerkleTreeVoucherInfo (OutputPointInfo) returns (IncrementalMerkleVoucherInfo)
- (void)getMerkleTreeVoucherInfoWithRequest:(OutputPointInfo *)request handler:(void(^)(IncrementalMerkleVoucherInfo *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToGetMerkleTreeVoucherInfoWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToGetMerkleTreeVoucherInfoWithRequest:(OutputPointInfo *)request handler:(void(^)(IncrementalMerkleVoucherInfo *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"GetMerkleTreeVoucherInfo"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[IncrementalMerkleVoucherInfo class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark ScanNoteByIvk (IvkDecryptParameters) returns (DecryptNotes)
- (void)scanNoteByIvkWithRequest:(IvkDecryptParameters *)request handler:(void(^)(DecryptNotes *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToScanNoteByIvkWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToScanNoteByIvkWithRequest:(IvkDecryptParameters *)request handler:(void(^)(DecryptNotes *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"ScanNoteByIvk"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[DecryptNotes class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark ScanAndMarkNoteByIvk (IvkDecryptAndMarkParameters) returns (DecryptNotesMarked)
- (void)scanAndMarkNoteByIvkWithRequest:(IvkDecryptAndMarkParameters *)request handler:(void(^)(DecryptNotesMarked *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToScanAndMarkNoteByIvkWithRequest:request handler:handler] start];
}
- (GRPCProtoCall *)RPCToScanAndMarkNoteByIvkWithRequest:(IvkDecryptAndMarkParameters *)request handler:(void(^)(DecryptNotesMarked *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"ScanAndMarkNoteByIvk"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[DecryptNotes class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark ScanNoteByOvk (IvkDecryptParameters) returns (DecryptNotes)
- (void)scanNoteByOvkWithRequest:(OvkDecryptParameters *)request handler:(void(^)(DecryptNotes *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToScanNoteByOvkWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToScanNoteByOvkWithRequest:(OvkDecryptParameters *)request handler:(void(^)(DecryptNotes *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"ScanNoteByOvk"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[DecryptNotes class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark GetSpendingKey (EmptyMessage) returns (BytesMessage)
- (void)getSpendingKeyWithRequest:(EmptyMessage *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToGetSpendingKeyWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToGetSpendingKeyWithRequest:(EmptyMessage *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"GetSpendingKey"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[BytesMessage class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark GetExpandedSpendingKey (BytesMessage) returns (ExpandedSpendingKeyMessage)
- (void)getExpandedSpendingKeyWithRequest:(BytesMessage *)request handler:(void(^)(ExpandedSpendingKeyMessage *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToGetExpandedSpendingKeyWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToGetExpandedSpendingKeyWithRequest:(BytesMessage *)request handler:(void(^)(ExpandedSpendingKeyMessage *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"GetExpandedSpendingKey"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[ExpandedSpendingKeyMessage class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark GetAkFromAsk (BytesMessage) returns (ExpandedSpendingKeyMessage)
- (void)getAkFromAskWithRequest:(BytesMessage *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToGetAkFromAskWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToGetAkFromAskWithRequest:(BytesMessage *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"GetAkFromAsk"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[BytesMessage class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark GetNkFromNsk (BytesMessage) returns (ExpandedSpendingKeyMessage)
- (void)getNkFromNskWithRequest:(BytesMessage *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToGetNkFromNskWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToGetNkFromNskWithRequest:(BytesMessage *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"GetNkFromNsk"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[BytesMessage class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark GetIncomingViewingKey (ViewingKeyMessage) returns (ExpandedSpendingKeyMessage)
- (void)getIncomingViewingKeyWithRequest:(ViewingKeyMessage *)request handler:(void(^)(IncomingViewingKeyMessage *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToGetIncomingViewingKeyWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToGetIncomingViewingKeyWithRequest:(ViewingKeyMessage *)request handler:(void(^)(IncomingViewingKeyMessage *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"GetIncomingViewingKey"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[IncomingViewingKeyMessage class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark GetDiversifier (EmptyMessage) returns (DiversifierMessage)
- (void)getDiversifierWithRequest:(EmptyMessage *)request handler:(void(^)(DiversifierMessage *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToGetDiversifierWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToGetDiversifierWithRequest:(EmptyMessage *)request handler:(void(^)(DiversifierMessage *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"GetDiversifier"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[DiversifierMessage class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark GetZenPaymentAddress (IncomingViewingKeyDiversifierMessage) returns (PaymentAddressMessage)
- (void)getZenPaymentAddressWithRequest:(IncomingViewingKeyDiversifierMessage *)request handler:(void(^)(PaymentAddressMessage *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToGetZenPaymentAddressWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToGetZenPaymentAddressWithRequest:(IncomingViewingKeyDiversifierMessage *)request handler:(void(^)(PaymentAddressMessage *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"GetZenPaymentAddress"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[PaymentAddressMessage class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark GetRcm (EmptyMessage) returns (BytesMessage)
- (void)getRcmWithRequest:(EmptyMessage *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToGetRcmWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToGetRcmWithRequest:(EmptyMessage *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"GetRcm"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[BytesMessage class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark IsSpend (NoteParameters) returns (BytesMessage)
- (void)isSpendWithRequest:(NoteParameters *)request handler:(void(^)(SpendResult *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToIsSpendWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToIsSpendWithRequest:(NoteParameters *)request handler:(void(^)(SpendResult *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"IsSpend"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[SpendResult class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark CreateShieldedTransactionWithoutSpendAuthSig (PrivateParametersWithoutAsk) returns (TransactionExtention)
- (void)createShieldedTransactionWithoutSpendAuthSigWithRequest:(PrivateParametersWithoutAsk *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToCreateShieldedTransactionWithoutSpendAuthSigWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToCreateShieldedTransactionWithoutSpendAuthSigWithRequest:(PrivateParametersWithoutAsk *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"CreateShieldedTransactionWithoutSpendAuthSig"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[TransactionExtention class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark GetShieldTransactionHash (TronTransaction) returns (BytesMessage)
- (void)getShieldTransactionHashWithRequest:(TronTransaction *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToGetShieldTransactionHashWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToGetShieldTransactionHashWithRequest:(TronTransaction *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"GetShieldTransactionHash"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[BytesMessage class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark CreateSpendAuthSig (SpendAuthSigParameters) returns (BytesMessage)
- (void)createSpendAuthSigWithRequest:(SpendAuthSigParameters *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToCreateSpendAuthSigWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToCreateSpendAuthSigWithRequest:(SpendAuthSigParameters *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"CreateSpendAuthSig"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[BytesMessage class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

#pragma mark CreateShieldNullifier (NfParameters) returns (BytesMessage)
- (void)createShieldNullifierWithRequest:(NfParameters *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler {
    [[self RPCToCreateShieldNullifierWithRequest:request handler:handler] start];
}

- (GRPCProtoCall *)RPCToCreateShieldNullifierWithRequest:(NfParameters *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler {
    return [self RPCToMethod:@"CreateShieldNullifier"
              requestsWriter:[GRXWriter writerWithValue:request]
               responseClass:[BytesMessage class]
          responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

@end

@implementation WalletSolidity

// Designated initializer
- (instancetype)initWithHost:(NSString *)host {
  self = [super initWithHost:host
                 packageName:@"protocol"
                 serviceName:@"WalletSolidity"];
  return self;
}

// Override superclass initializer to disallow different package and service names.
- (instancetype)initWithHost:(NSString *)host
                 packageName:(NSString *)packageName
                 serviceName:(NSString *)serviceName {
  return [self initWithHost:host];
}

#pragma mark - Class Methods

+ (instancetype)serviceWithHost:(NSString *)host {
  return [[self alloc] initWithHost:host];
}

#pragma mark - Method Implementations

#pragma mark GetAccount(Account) returns (Account)

- (void)getAccountWithRequest:(TronAccount *)request handler:(void(^)(TronAccount *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetAccountWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetAccountWithRequest:(TronAccount *)request handler:(void(^)(TronAccount *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetAccount"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TronAccount class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetAccountById(Account) returns (Account)

- (void)getAccountByIdWithRequest:(TronAccount *)request handler:(void(^)(TronAccount *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetAccountByIdWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetAccountByIdWithRequest:(TronAccount *)request handler:(void(^)(TronAccount *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetAccountById"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TronAccount class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark ListWitnesses(EmptyMessage) returns (WitnessList)

- (void)listWitnessesWithRequest:(EmptyMessage *)request handler:(void(^)(WitnessList *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToListWitnessesWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToListWitnessesWithRequest:(EmptyMessage *)request handler:(void(^)(WitnessList *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"ListWitnesses"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[WitnessList class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetAssetIssueList(EmptyMessage) returns (AssetIssueList)

- (void)getAssetIssueListWithRequest:(EmptyMessage *)request handler:(void(^)(AssetIssueList *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetAssetIssueListWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetAssetIssueListWithRequest:(EmptyMessage *)request handler:(void(^)(AssetIssueList *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetAssetIssueList"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[AssetIssueList class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetPaginatedAssetIssueList(PaginatedMessage) returns (AssetIssueList)

- (void)getPaginatedAssetIssueListWithRequest:(PaginatedMessage *)request handler:(void(^)(AssetIssueList *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetPaginatedAssetIssueListWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetPaginatedAssetIssueListWithRequest:(PaginatedMessage *)request handler:(void(^)(AssetIssueList *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetPaginatedAssetIssueList"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[AssetIssueList class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetNowBlock(EmptyMessage) returns (Block)

/**
 * Please use GetNowBlock2 instead of this function.
 */
- (void)getNowBlockWithRequest:(EmptyMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetNowBlockWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Please use GetNowBlock2 instead of this function.
 */
- (GRPCProtoCall *)RPCToGetNowBlockWithRequest:(EmptyMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetNowBlock"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[Block class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetNowBlock2(EmptyMessage) returns (BlockExtention)

/**
 * Use this function instead of GetNowBlock.
 */
- (void)getNowBlock2WithRequest:(EmptyMessage *)request handler:(void(^)(BlockExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetNowBlock2WithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Use this function instead of GetNowBlock.
 */
- (GRPCProtoCall *)RPCToGetNowBlock2WithRequest:(EmptyMessage *)request handler:(void(^)(BlockExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetNowBlock2"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[BlockExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetBlockByNum(NumberMessage) returns (Block)

/**
 * Please use GetBlockByNum2 instead of this function.
 */
- (void)getBlockByNumWithRequest:(NumberMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetBlockByNumWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Please use GetBlockByNum2 instead of this function.
 */
- (GRPCProtoCall *)RPCToGetBlockByNumWithRequest:(NumberMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetBlockByNum"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[Block class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetBlockByNum2(NumberMessage) returns (BlockExtention)

/**
 * Use this function instead of GetBlockByNum.
 */
- (void)getBlockByNum2WithRequest:(NumberMessage *)request handler:(void(^)(BlockExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetBlockByNum2WithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Use this function instead of GetBlockByNum.
 */
- (GRPCProtoCall *)RPCToGetBlockByNum2WithRequest:(NumberMessage *)request handler:(void(^)(BlockExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetBlockByNum2"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[BlockExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetTransactionCountByBlockNum(NumberMessage) returns (NumberMessage)

- (void)getTransactionCountByBlockNumWithRequest:(NumberMessage *)request handler:(void(^)(NumberMessage *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetTransactionCountByBlockNumWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetTransactionCountByBlockNumWithRequest:(NumberMessage *)request handler:(void(^)(NumberMessage *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetTransactionCountByBlockNum"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[NumberMessage class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetTransactionById(BytesMessage) returns (Transaction)

- (void)getTransactionByIdWithRequest:(BytesMessage *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetTransactionByIdWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetTransactionByIdWithRequest:(BytesMessage *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetTransactionById"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TronTransaction class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetTransactionInfoById(BytesMessage) returns (TransactionInfo)

- (void)getTransactionInfoByIdWithRequest:(BytesMessage *)request handler:(void(^)(TransactionInfo *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetTransactionInfoByIdWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetTransactionInfoByIdWithRequest:(BytesMessage *)request handler:(void(^)(TransactionInfo *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetTransactionInfoById"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionInfo class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}

@end
@implementation WalletExtension

//// Designated initializer
//- (instancetype)initWithHost:(NSString *)host {
//  self = [super initWithHost:host
//                 packageName:@"protocol"
//                 serviceName:@"WalletExtension"];
//  return self;
//}

// Override superclass initializer to disallow different package and service names.
- (instancetype)initWithHost:(NSString *)host
                 packageName:(NSString *)packageName
                 serviceName:(NSString *)serviceName {
  return [self initWithHost:host];
}

#pragma mark - Class Methods

+ (instancetype)serviceWithHost:(NSString *)host {
  return [[self alloc] initWithHost:host];
}

#pragma mark - Method Implementations

#pragma mark GetTransactionsFromThis(AccountPaginated) returns (TransactionList)

/**
 * Please use GetTransactionsFromThis2 instead of this function.
 */
- (void)getTransactionsFromThisWithRequest:(AccountPaginated *)request handler:(void(^)(TransactionList *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetTransactionsFromThisWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Please use GetTransactionsFromThis2 instead of this function.
 */
- (GRPCProtoCall *)RPCToGetTransactionsFromThisWithRequest:(AccountPaginated *)request handler:(void(^)(TransactionList *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetTransactionsFromThis"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionList class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetTransactionsFromThis2(AccountPaginated) returns (TransactionListExtention)

/**
 * Use this function instead of GetTransactionsFromThis.
 */
- (void)getTransactionsFromThis2WithRequest:(AccountPaginated *)request handler:(void(^)(TransactionListExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetTransactionsFromThis2WithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Use this function instead of GetTransactionsFromThis.
 */
- (GRPCProtoCall *)RPCToGetTransactionsFromThis2WithRequest:(AccountPaginated *)request handler:(void(^)(TransactionListExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetTransactionsFromThis2"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionListExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetTransactionsToThis(AccountPaginated) returns (TransactionList)

/**
 * Please use GetTransactionsToThis2 instead of this function.
 */
- (void)getTransactionsToThisWithRequest:(AccountPaginated *)request handler:(void(^)(TransactionList *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetTransactionsToThisWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Please use GetTransactionsToThis2 instead of this function.
 */
- (GRPCProtoCall *)RPCToGetTransactionsToThisWithRequest:(AccountPaginated *)request handler:(void(^)(TransactionList *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetTransactionsToThis"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionList class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetTransactionsToThis2(AccountPaginated) returns (TransactionListExtention)

/**
 * Use this function instead of GetTransactionsToThis.
 */
- (void)getTransactionsToThis2WithRequest:(AccountPaginated *)request handler:(void(^)(TransactionListExtention *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetTransactionsToThis2WithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * Use this function instead of GetTransactionsToThis.
 */
- (GRPCProtoCall *)RPCToGetTransactionsToThis2WithRequest:(AccountPaginated *)request handler:(void(^)(TransactionListExtention *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetTransactionsToThis2"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[TransactionListExtention class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
@end
@implementation Database

// Designated initializer
- (instancetype)initWithHost:(NSString *)host {
  self = [super initWithHost:host
                 packageName:@"protocol"
                 serviceName:@"Database"];
  return self;
}

// Override superclass initializer to disallow different package and service names.
- (instancetype)initWithHost:(NSString *)host
                 packageName:(NSString *)packageName
                 serviceName:(NSString *)serviceName {
  return [self initWithHost:host];
}

#pragma mark - Class Methods

+ (instancetype)serviceWithHost:(NSString *)host {
  return [[self alloc] initWithHost:host];
}

#pragma mark - Method Implementations

#pragma mark getBlockReference(EmptyMessage) returns (BlockReference)

/**
 * for tapos
 */
- (void)getBlockReferenceWithRequest:(EmptyMessage *)request handler:(void(^)(BlockReference *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCTogetBlockReferenceWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
/**
 * for tapos
 */
- (GRPCProtoCall *)RPCTogetBlockReferenceWithRequest:(EmptyMessage *)request handler:(void(^)(BlockReference *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"getBlockReference"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[BlockReference class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetDynamicProperties(EmptyMessage) returns (DynamicProperties)

- (void)getDynamicPropertiesWithRequest:(EmptyMessage *)request handler:(void(^)(DynamicProperties *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetDynamicPropertiesWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetDynamicPropertiesWithRequest:(EmptyMessage *)request handler:(void(^)(DynamicProperties *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetDynamicProperties"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[DynamicProperties class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetNowBlock(EmptyMessage) returns (Block)

- (void)getNowBlockWithRequest:(EmptyMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetNowBlockWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetNowBlockWithRequest:(EmptyMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetNowBlock"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[Block class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
#pragma mark GetBlockByNum(NumberMessage) returns (Block)

- (void)getBlockByNumWithRequest:(NumberMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler{
  [[self RPCToGetBlockByNumWithRequest:request handler:handler] start];
}
// Returns a not-yet-started RPC object.
- (GRPCProtoCall *)RPCToGetBlockByNumWithRequest:(NumberMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler{
  return [self RPCToMethod:@"GetBlockByNum"
            requestsWriter:[GRXWriter writerWithValue:request]
             responseClass:[Block class]
        responsesWriteable:[GRXWriteable writeableWithSingleHandler:handler]];
}
@end
@implementation Network

// Designated initializer
- (instancetype)initWithHost:(NSString *)host {
  self = [super initWithHost:host
                 packageName:@"protocol"
                 serviceName:@"Network"];
  return self;
}

// Override superclass initializer to disallow different package and service names.
- (instancetype)initWithHost:(NSString *)host
                 packageName:(NSString *)packageName
                 serviceName:(NSString *)serviceName {
  return [self initWithHost:host];
}

#pragma mark - Class Methods

+ (instancetype)serviceWithHost:(NSString *)host {
  return [[self alloc] initWithHost:host];
}

#pragma mark - Method Implementations

@end
#endif
