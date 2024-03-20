#if !defined(GPB_GRPC_FORWARD_DECLARE_MESSAGE_PROTO) || !GPB_GRPC_FORWARD_DECLARE_MESSAGE_PROTO
#import "Api_Tron.pbobjc.h"
#endif

#if !defined(GPB_GRPC_PROTOCOL_ONLY) || !GPB_GRPC_PROTOCOL_ONLY
#import <ProtoRPC/ProtoService.h>
#import <ProtoRPC/ProtoRPC.h>
#import <RxLibrary/GRXWriteable.h>
#import <RxLibrary/GRXWriter.h>
#endif

#if defined(GPB_GRPC_FORWARD_DECLARE_MESSAGE_PROTO) && GPB_GRPC_FORWARD_DECLARE_MESSAGE_PROTO
  @class TronAccount;
  @class AccountCreateContract;
  @class AccountNetMessage;
  @class AccountPaginated;
  @class AccountResourceMessage;
  @class AccountUpdateContract;
  @class AddressPrKeyPairMessage;
  @class AssetIssueContract;
  @class AssetIssueList;
  @class Block;
  @class BlockExtention;
  @class BlockLimit;
  @class BlockList;
  @class BlockListExtention;
  @class BlockReference;
  @class BuyStorageBytesContract;
  @class BuyStorageContract;
  @class BytesMessage;
  @class ChainParameters;
  @class CreateSmartContract;
  @class DynamicProperties;
  @class EasyTransferByPrivateMessage;
  @class EasyTransferMessage;
  @class EasyTransferResponse;
  @class EmptyMessage;
  @class Exchange;
  @class ExchangeCreateContract;
  @class ExchangeInjectContract;
  @class ExchangeList;
  @class ExchangeTransactionContract;
  @class ExchangeWithdrawContract;
  @class FreezeBalanceContract;
  @class NodeList;
  @class NumberMessage;
  @class PaginatedMessage;
  @class ParticipateAssetIssueContract;
  @class Proposal;
  @class ProposalApproveContract;
  @class ProposalCreateContract;
  @class ProposalDeleteContract;
  @class ProposalList;
  @class Return;
  @class TronTransaction;
  @class SellStorageContract;
  @class SetAccountIdContract;
  @class SmartContract;
  @class TransactionExtention;
  @class TransactionInfo;
  @class TransactionList;
  @class TransactionListExtention;
  @class TransactionSign;
  @class TransferAssetContract;
  @class TransferContract;
  @class TriggerSmartContract;
  @class UnfreezeAssetContract;
  @class UnfreezeBalanceContract;
  @class UpdateAssetContract;
  @class UpdateSettingContract;
  @class VoteWitnessContract;
  @class WithdrawBalanceContract;
  @class WitnessCreateContract;
  @class WitnessList;
  @class WitnessUpdateContract;
  @class TransactionApprovedList;
#else
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
#endif

@class GRPCProtoCall;


NS_ASSUME_NONNULL_BEGIN

@protocol TWallet <NSObject>

#pragma mark GetAccount(TronAccount) returns (TronAccount)

- (void)getAccountWithRequest:(TronAccount *)request handler:(void(^)(TronAccount *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetAccountWithRequest:(TronAccount *)request handler:(void(^)(TronAccount *_Nullable response, NSError *_Nullable error))handler;

#pragma mark GetAccountById(Account) returns (Account)

- (void)getAccountByIdWithRequest:(TronAccount *)request handler:(void(^)(TronAccount *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetAccountByIdWithRequest:(TronAccount *)request handler:(void(^)(TronAccount *_Nullable response, NSError *_Nullable error))handler;

#pragma mark CreateTransaction(TransferContract) returns (Transaction)

/**
 * Please use CreateTransaction2 instead of this function.
 */
- (void)createTransactionWithRequest:(TransferContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;

/**
 * Please use CreateTransaction2 instead of this function.
 */
- (GRPCProtoCall *)RPCToCreateTransactionWithRequest:(TransferContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;


#pragma mark CreateTransaction2(TransferContract) returns (TransactionExtention)

/**
 * Use this function instead of CreateTransaction.
 */
- (void)createTransaction2WithRequest:(TransferContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

/**
 * Use this function instead of CreateTransaction.
 */
- (GRPCProtoCall *)RPCToCreateTransaction2WithRequest:(TransferContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark BroadcastTransaction(Transaction) returns (Return)

- (void)broadcastTransactionWithRequest:(TronTransaction *)request handler:(void(^)(Return *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToBroadcastTransactionWithRequest:(TronTransaction *)request handler:(void(^)(Return *_Nullable response, NSError *_Nullable error))handler;


#pragma mark UpdateAccount(AccountUpdateContract) returns (Transaction)

/**
 * Please use UpdateAccount2 instead of this function.
 */
- (void)updateAccountWithRequest:(AccountUpdateContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;

/**
 * Please use UpdateAccount2 instead of this function.
 */
- (GRPCProtoCall *)RPCToUpdateAccountWithRequest:(AccountUpdateContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;


#pragma mark SetAccountId(SetAccountIdContract) returns (Transaction)

- (void)setAccountIdWithRequest:(SetAccountIdContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToSetAccountIdWithRequest:(SetAccountIdContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;


#pragma mark UpdateAccount2(AccountUpdateContract) returns (TransactionExtention)

/**
 * Use this function instead of UpdateAccount.
 */
- (void)updateAccount2WithRequest:(AccountUpdateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

/**
 * Use this function instead of UpdateAccount.
 */
- (GRPCProtoCall *)RPCToUpdateAccount2WithRequest:(AccountUpdateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark VoteWitnessAccount(VoteWitnessContract) returns (Transaction)

/**
 * Please use VoteWitnessAccount2 instead of this function.
 */
- (void)voteWitnessAccountWithRequest:(VoteWitnessContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;

/**
 * Please use VoteWitnessAccount2 instead of this function.
 */
- (GRPCProtoCall *)RPCToVoteWitnessAccountWithRequest:(VoteWitnessContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;


#pragma mark UpdateSetting(UpdateSettingContract) returns (TransactionExtention)

/**
 * modify the consume_user_resource_percent
 */
- (void)updateSettingWithRequest:(UpdateSettingContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

/**
 * modify the consume_user_resource_percent
 */
- (GRPCProtoCall *)RPCToUpdateSettingWithRequest:(UpdateSettingContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark VoteWitnessAccount2(VoteWitnessContract) returns (TransactionExtention)

/**
 * Use this function instead of VoteWitnessAccount.
 */
- (void)voteWitnessAccount2WithRequest:(VoteWitnessContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

/**
 * Use this function instead of VoteWitnessAccount.
 */
- (GRPCProtoCall *)RPCToVoteWitnessAccount2WithRequest:(VoteWitnessContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark CreateAssetIssue(AssetIssueContract) returns (Transaction)

/**
 * Please use CreateAssetIssue2 instead of this function.
 */
- (void)createAssetIssueWithRequest:(AssetIssueContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;

/**
 * Please use CreateAssetIssue2 instead of this function.
 */
- (GRPCProtoCall *)RPCToCreateAssetIssueWithRequest:(AssetIssueContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;


#pragma mark CreateAssetIssue2(AssetIssueContract) returns (TransactionExtention)

/**
 * Use this function instead of CreateAssetIssue.
 */
- (void)createAssetIssue2WithRequest:(AssetIssueContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

/**
 * Use this function instead of CreateAssetIssue.
 */
- (GRPCProtoCall *)RPCToCreateAssetIssue2WithRequest:(AssetIssueContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark UpdateWitness(WitnessUpdateContract) returns (Transaction)

/**
 * Please use UpdateWitness2 instead of this function.
 */
- (void)updateWitnessWithRequest:(WitnessUpdateContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;

/**
 * Please use UpdateWitness2 instead of this function.
 */
- (GRPCProtoCall *)RPCToUpdateWitnessWithRequest:(WitnessUpdateContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;


#pragma mark UpdateWitness2(WitnessUpdateContract) returns (TransactionExtention)

/**
 * Use this function instead of UpdateWitness.
 */
- (void)updateWitness2WithRequest:(WitnessUpdateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

/**
 * Use this function instead of UpdateWitness.
 */
- (GRPCProtoCall *)RPCToUpdateWitness2WithRequest:(WitnessUpdateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark CreateAccount(AccountCreateContract) returns (Transaction)

/**
 * Please use CreateAccount2 instead of this function.
 */
- (void)createAccountWithRequest:(AccountCreateContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;

/**
 * Please use CreateAccount2 instead of this function.
 */
- (GRPCProtoCall *)RPCToCreateAccountWithRequest:(AccountCreateContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;


#pragma mark CreateAccount2(AccountCreateContract) returns (TransactionExtention)

/**
 * Use this function instead of CreateAccount.
 */
- (void)createAccount2WithRequest:(AccountCreateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

/**
 * Use this function instead of CreateAccount.
 */
- (GRPCProtoCall *)RPCToCreateAccount2WithRequest:(AccountCreateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark CreateWitness(WitnessCreateContract) returns (Transaction)

/**
 * Please use CreateWitness2 instead of this function.
 */
- (void)createWitnessWithRequest:(WitnessCreateContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;

/**
 * Please use CreateWitness2 instead of this function.
 */
- (GRPCProtoCall *)RPCToCreateWitnessWithRequest:(WitnessCreateContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;


#pragma mark CreateWitness2(WitnessCreateContract) returns (TransactionExtention)

/**
 * Use this function instead of CreateWitness.
 */
- (void)createWitness2WithRequest:(WitnessCreateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

/**
 * Use this function instead of CreateWitness.
 */
- (GRPCProtoCall *)RPCToCreateWitness2WithRequest:(WitnessCreateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark TransferAsset(TransferAssetContract) returns (Transaction)

/**
 * Please use TransferAsset2 instead of this function.
 */
- (void)transferAssetWithRequest:(TransferAssetContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;

/**
 * Please use TransferAsset2 instead of this function.
 */
- (GRPCProtoCall *)RPCToTransferAssetWithRequest:(TransferAssetContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;


#pragma mark TransferAsset2(TransferAssetContract) returns (TransactionExtention)

/**
 * Use this function instead of TransferAsset.
 */
- (void)transferAsset2WithRequest:(TransferAssetContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

/**
 * Use this function instead of TransferAsset.
 */
- (GRPCProtoCall *)RPCToTransferAsset2WithRequest:(TransferAssetContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark ParticipateAssetIssue(ParticipateAssetIssueContract) returns (Transaction)

/**
 * Please use ParticipateAssetIssue2 instead of this function.
 */
- (void)participateAssetIssueWithRequest:(ParticipateAssetIssueContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;

/**
 * Please use ParticipateAssetIssue2 instead of this function.
 */
- (GRPCProtoCall *)RPCToParticipateAssetIssueWithRequest:(ParticipateAssetIssueContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;


#pragma mark ParticipateAssetIssue2(ParticipateAssetIssueContract) returns (TransactionExtention)

/**
 * Use this function instead of ParticipateAssetIssue.
 */
- (void)participateAssetIssue2WithRequest:(ParticipateAssetIssueContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

/**
 * Use this function instead of ParticipateAssetIssue.
 */
- (GRPCProtoCall *)RPCToParticipateAssetIssue2WithRequest:(ParticipateAssetIssueContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark FreezeBalance(FreezeBalanceContract) returns (Transaction)

/**
 * Please use FreezeBalance2 instead of this function.
 */
- (void)freezeBalanceWithRequest:(FreezeBalanceContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;

/**
 * Please use FreezeBalance2 instead of this function.
 */
- (GRPCProtoCall *)RPCToFreezeBalanceWithRequest:(FreezeBalanceContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;


#pragma mark FreezeBalance2(FreezeBalanceContract) returns (TransactionExtention)

/**
 * Use this function instead of FreezeBalance.
 */
- (void)freezeBalance2WithRequest:(FreezeBalanceContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

/**
 * Use this function instead of FreezeBalance.
 */
- (GRPCProtoCall *)RPCToFreezeBalance2WithRequest:(FreezeBalanceContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark FreezeBalanceV2(FreezeBalanceV2Contract) returns (TransactionExtention)

- (void)freezeBalanceV2WithRequest:(FreezeBalanceV2Contract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToFreezeBalanceV2WithRequest:(FreezeBalanceV2Contract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

#pragma mark UnfreezeBalanceV2(UnfreezeBalanceV2Contract) returns (TransactionExtention)

- (void)unfreezeBalanceV2WithRequest:(UnfreezeBalanceV2Contract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToUnfreezeBalanceV2WithRequest:(UnfreezeBalanceV2Contract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

#pragma mark WithdrawExpireUnfreeze(WithdrawExpireUnfreezeContract) returns (TransactionExtention)

- (void)withdrawExpireUnfreezeWithRequest:(WithdrawExpireUnfreezeContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToWithdrawExpireUnfreezeWithRequest:(WithdrawExpireUnfreezeContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

#pragma mark DelegateResource(DelegateResourceContract) returns (TransactionExtention)

- (void)delegateResourceWithRequest:(DelegateResourceContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToDelegateResourceWithRequest:(DelegateResourceContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

#pragma mark UnDelegateResource(UnDelegateResourceContract) returns (TransactionExtention)

- (void)unDelegateResourceWithRequest:(UnDelegateResourceContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToUnDelegateResourceWithRequestWithRequest:(UnDelegateResourceContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

#pragma mark CanDelegatedMaxSize(CanDelegatedMaxSizeRequestMessage) returns (CanDelegatedMaxSizeResponseMessage)

- (void)getCanDelegatedMaxSizeWithRequest:(CanDelegatedMaxSizeRequestMessage *)request handler:(void(^)(CanDelegatedMaxSizeResponseMessage *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetCanDelegatedMaxSizeWithRequest:(CanDelegatedMaxSizeRequestMessage *)request handler:(void(^)(CanDelegatedMaxSizeResponseMessage *_Nullable response, NSError *_Nullable error))handler;

#pragma mark CanWithdrawUnfreezeAmount(CanWithdrawUnfreezeAmountRequestMessage) returns (CanWithdrawUnfreezeAmountResponseMessage)

- (void)getCanWithdrawUnfreezeAmountWithRequest:(CanWithdrawUnfreezeAmountRequestMessage *)request handler:(void(^)(CanWithdrawUnfreezeAmountResponseMessage *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToCanWithdrawUnfreezeAmountRequest:(CanWithdrawUnfreezeAmountRequestMessage *)request handler:(void(^)(CanWithdrawUnfreezeAmountResponseMessage *_Nullable response, NSError *_Nullable error))handler;

#pragma mark GetAvailableUnfreezeCount(GetAvailableUnfreezeCountRequestMessage) returns (GetAvailableUnfreezeCountResponseMessage)

- (void)GetAvailableUnfreezeCountWithRequest:(GetAvailableUnfreezeCountRequestMessage *)request handler:(void(^)(GetAvailableUnfreezeCountResponseMessage *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetAvailableUnfreezeCountRequest:(GetAvailableUnfreezeCountRequestMessage *)request handler:(void(^)(GetAvailableUnfreezeCountResponseMessage *_Nullable response, NSError *_Nullable error))handler;

#pragma mark UnfreezeBalance(UnfreezeBalanceContract) returns (Transaction)

/**
 * Please use UnfreezeBalance2 instead of this function.
 */
- (void)unfreezeBalanceWithRequest:(UnfreezeBalanceContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;

/**
 * Please use UnfreezeBalance2 instead of this function.
 */
- (GRPCProtoCall *)RPCToUnfreezeBalanceWithRequest:(UnfreezeBalanceContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;


#pragma mark UnfreezeBalance2(UnfreezeBalanceContract) returns (TransactionExtention)

/**
 * Use this function instead of UnfreezeBalance.
 */
- (void)unfreezeBalance2WithRequest:(UnfreezeBalanceContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

/**
 * Use this function instead of UnfreezeBalance.
 */
- (GRPCProtoCall *)RPCToUnfreezeBalance2WithRequest:(UnfreezeBalanceContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark UnfreezeAsset(UnfreezeAssetContract) returns (Transaction)

/**
 * Please use UnfreezeAsset2 instead of this function.
 */
- (void)unfreezeAssetWithRequest:(UnfreezeAssetContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;

/**
 * Please use UnfreezeAsset2 instead of this function.
 */
- (GRPCProtoCall *)RPCToUnfreezeAssetWithRequest:(UnfreezeAssetContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;


#pragma mark UnfreezeAsset2(UnfreezeAssetContract) returns (TransactionExtention)

/**
 * Use this function instead of UnfreezeAsset.
 */
- (void)unfreezeAsset2WithRequest:(UnfreezeAssetContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

/**
 * Use this function instead of UnfreezeAsset.
 */
- (GRPCProtoCall *)RPCToUnfreezeAsset2WithRequest:(UnfreezeAssetContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark WithdrawBalance(WithdrawBalanceContract) returns (Transaction)

/**
 * Please use WithdrawBalance2 instead of this function.
 */
- (void)withdrawBalanceWithRequest:(WithdrawBalanceContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;

/**
 * Please use WithdrawBalance2 instead of this function.
 */
- (GRPCProtoCall *)RPCToWithdrawBalanceWithRequest:(WithdrawBalanceContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;


#pragma mark WithdrawBalance2(WithdrawBalanceContract) returns (TransactionExtention)

/**
 * Use this function instead of WithdrawBalance.
 */
- (void)withdrawBalance2WithRequest:(WithdrawBalanceContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

/**
 * Use this function instead of WithdrawBalance.
 */
- (GRPCProtoCall *)RPCToWithdrawBalance2WithRequest:(WithdrawBalanceContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark UpdateAsset(UpdateAssetContract) returns (Transaction)

/**
 * Please use UpdateAsset2 instead of this function.
 */
- (void)updateAssetWithRequest:(UpdateAssetContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;

/**
 * Please use UpdateAsset2 instead of this function.
 */
- (GRPCProtoCall *)RPCToUpdateAssetWithRequest:(UpdateAssetContract *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;


#pragma mark UpdateAsset2(UpdateAssetContract) returns (TransactionExtention)

/**
 * Use this function instead of UpdateAsset.
 */
- (void)updateAsset2WithRequest:(UpdateAssetContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

/**
 * Use this function instead of UpdateAsset.
 */
- (GRPCProtoCall *)RPCToUpdateAsset2WithRequest:(UpdateAssetContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark ProposalCreate(ProposalCreateContract) returns (TransactionExtention)

- (void)proposalCreateWithRequest:(ProposalCreateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToProposalCreateWithRequest:(ProposalCreateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark ProposalApprove(ProposalApproveContract) returns (TransactionExtention)

- (void)proposalApproveWithRequest:(ProposalApproveContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToProposalApproveWithRequest:(ProposalApproveContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark ProposalDelete(ProposalDeleteContract) returns (TransactionExtention)

- (void)proposalDeleteWithRequest:(ProposalDeleteContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToProposalDeleteWithRequest:(ProposalDeleteContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark BuyStorage(BuyStorageContract) returns (TransactionExtention)

- (void)buyStorageWithRequest:(BuyStorageContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToBuyStorageWithRequest:(BuyStorageContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark BuyStorageBytes(BuyStorageBytesContract) returns (TransactionExtention)

- (void)buyStorageBytesWithRequest:(BuyStorageBytesContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToBuyStorageBytesWithRequest:(BuyStorageBytesContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark SellStorage(SellStorageContract) returns (TransactionExtention)

- (void)sellStorageWithRequest:(SellStorageContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToSellStorageWithRequest:(SellStorageContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark ExchangeCreate(ExchangeCreateContract) returns (TransactionExtention)

- (void)exchangeCreateWithRequest:(ExchangeCreateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToExchangeCreateWithRequest:(ExchangeCreateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark ExchangeInject(ExchangeInjectContract) returns (TransactionExtention)

- (void)exchangeInjectWithRequest:(ExchangeInjectContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToExchangeInjectWithRequest:(ExchangeInjectContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark ExchangeWithdraw(ExchangeWithdrawContract) returns (TransactionExtention)

- (void)exchangeWithdrawWithRequest:(ExchangeWithdrawContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToExchangeWithdrawWithRequest:(ExchangeWithdrawContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark ExchangeTransaction(ExchangeTransactionContract) returns (TransactionExtention)

- (void)exchangeTransactionWithRequest:(ExchangeTransactionContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToExchangeTransactionWithRequest:(ExchangeTransactionContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark ListNodes(EmptyMessage) returns (NodeList)

- (void)listNodesWithRequest:(EmptyMessage *)request handler:(void(^)(NodeList *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToListNodesWithRequest:(EmptyMessage *)request handler:(void(^)(NodeList *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetAssetIssueByAccount(Account) returns (AssetIssueList)

- (void)getAssetIssueByAccountWithRequest:(TronAccount *)request handler:(void(^)(AssetIssueList *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetAssetIssueByAccountWithRequest:(TronAccount *)request handler:(void(^)(AssetIssueList *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetAccountNet(Account) returns (AccountNetMessage)

- (void)getAccountNetWithRequest:(TronAccount *)request handler:(void(^)(AccountNetMessage *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetAccountNetWithRequest:(TronAccount *)request handler:(void(^)(AccountNetMessage *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetAccountResource(Account) returns (AccountResourceMessage)

- (void)getAccountResourceWithRequest:(TronAccount *)request handler:(void(^)(AccountResourceMessage *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetAccountResourceWithRequest:(TronAccount *)request handler:(void(^)(AccountResourceMessage *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetAssetIssueByName(BytesMessage) returns (AssetIssueContract)

- (void)getAssetIssueByNameWithRequest:(BytesMessage *)request handler:(void(^)(AssetIssueContract *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetAssetIssueByNameWithRequest:(BytesMessage *)request handler:(void(^)(AssetIssueContract *_Nullable response, NSError *_Nullable error))handler;


#pragma mark CancelAllUnfreezeV2(CancelAllUnfreezeV2Contract) returns (TransactionExtention)

- (void)cancelAllUnfreezeV2WithRequest:(CancelAllUnfreezeV2Contract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToCancelAllUnfreezeV2WithRequestWithRequest:(CancelAllUnfreezeV2Contract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

#pragma mark GetNowBlock(EmptyMessage) returns (Block)

/**
 * Please use GetNowBlock2 instead of this function.
 */
- (void)getNowBlockWithRequest:(EmptyMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler;

/**
 * Please use GetNowBlock2 instead of this function.
 */
- (GRPCProtoCall *)RPCToGetNowBlockWithRequest:(EmptyMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetNowBlock2(EmptyMessage) returns (BlockExtention)

/**
 * Use this function instead of GetNowBlock.
 */
- (void)getNowBlock2WithRequest:(EmptyMessage *)request handler:(void(^)(BlockExtention *_Nullable response, NSError *_Nullable error))handler;

/**
 * Use this function instead of GetNowBlock.
 */
- (GRPCProtoCall *)RPCToGetNowBlock2WithRequest:(EmptyMessage *)request handler:(void(^)(BlockExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetBlockByNum(NumberMessage) returns (Block)

/**
 * Please use GetBlockByNum2 instead of this function.
 */
- (void)getBlockByNumWithRequest:(NumberMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler;

/**
 * Please use GetBlockByNum2 instead of this function.
 */
- (GRPCProtoCall *)RPCToGetBlockByNumWithRequest:(NumberMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetBlockByNum2(NumberMessage) returns (BlockExtention)

/**
 * Use this function instead of GetBlockByNum.
 */
- (void)getBlockByNum2WithRequest:(NumberMessage *)request handler:(void(^)(BlockExtention *_Nullable response, NSError *_Nullable error))handler;

/**
 * Use this function instead of GetBlockByNum.
 */
- (GRPCProtoCall *)RPCToGetBlockByNum2WithRequest:(NumberMessage *)request handler:(void(^)(BlockExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetTransactionCountByBlockNum(NumberMessage) returns (NumberMessage)

- (void)getTransactionCountByBlockNumWithRequest:(NumberMessage *)request handler:(void(^)(NumberMessage *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetTransactionCountByBlockNumWithRequest:(NumberMessage *)request handler:(void(^)(NumberMessage *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetBlockById(BytesMessage) returns (Block)

- (void)getBlockByIdWithRequest:(BytesMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetBlockByIdWithRequest:(BytesMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetBlockByLimitNext(BlockLimit) returns (BlockList)

/**
 * Please use GetBlockByLimitNext2 instead of this function.
 */
- (void)getBlockByLimitNextWithRequest:(BlockLimit *)request handler:(void(^)(BlockList *_Nullable response, NSError *_Nullable error))handler;

/**
 * Please use GetBlockByLimitNext2 instead of this function.
 */
- (GRPCProtoCall *)RPCToGetBlockByLimitNextWithRequest:(BlockLimit *)request handler:(void(^)(BlockList *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetBlockByLimitNext2(BlockLimit) returns (BlockListExtention)

/**
 * Use this function instead of GetBlockByLimitNext.
 */
- (void)getBlockByLimitNext2WithRequest:(BlockLimit *)request handler:(void(^)(BlockListExtention *_Nullable response, NSError *_Nullable error))handler;

/**
 * Use this function instead of GetBlockByLimitNext.
 */
- (GRPCProtoCall *)RPCToGetBlockByLimitNext2WithRequest:(BlockLimit *)request handler:(void(^)(BlockListExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetBlockByLatestNum(NumberMessage) returns (BlockList)

/**
 * Please use GetBlockByLatestNum2 instead of this function.
 */
- (void)getBlockByLatestNumWithRequest:(NumberMessage *)request handler:(void(^)(BlockList *_Nullable response, NSError *_Nullable error))handler;

/**
 * Please use GetBlockByLatestNum2 instead of this function.
 */
- (GRPCProtoCall *)RPCToGetBlockByLatestNumWithRequest:(NumberMessage *)request handler:(void(^)(BlockList *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetBlockByLatestNum2(NumberMessage) returns (BlockListExtention)

/**
 * Use this function instead of GetBlockByLatestNum.
 */
- (void)getBlockByLatestNum2WithRequest:(NumberMessage *)request handler:(void(^)(BlockListExtention *_Nullable response, NSError *_Nullable error))handler;

/**
 * Use this function instead of GetBlockByLatestNum.
 */
- (GRPCProtoCall *)RPCToGetBlockByLatestNum2WithRequest:(NumberMessage *)request handler:(void(^)(BlockListExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetTransactionById(BytesMessage) returns (Transaction)

- (void)getTransactionByIdWithRequest:(BytesMessage *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetTransactionByIdWithRequest:(BytesMessage *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;


#pragma mark DeployContract(CreateSmartContract) returns (TransactionExtention)

- (void)deployContractWithRequest:(CreateSmartContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToDeployContractWithRequest:(CreateSmartContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

#pragma mark ClearABIContract(ClearABIContract) returns (TransactionExtention)

- (void)clearABIContractWithRequest:(ClearABIContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToClearABIContractWithRequest:(ClearABIContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

#pragma mark GetContract(BytesMessage) returns (SmartContract)

- (void)getContractWithRequest:(BytesMessage *)request handler:(void(^)(SmartContract *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetContractWithRequest:(BytesMessage *)request handler:(void(^)(SmartContract *_Nullable response, NSError *_Nullable error))handler;


#pragma mark TriggerContract(TriggerSmartContract) returns (TransactionExtention)

- (void)triggerContractWithRequest:(TriggerSmartContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToTriggerContractWithRequest:(TriggerSmartContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

#pragma mark TriggerConstantContract(TriggerSmartContract) returns (TransactionExtention)

- (void)triggerConstantContractWithRequest:(TriggerSmartContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToTriggerConstantContractWithRequest:(TriggerSmartContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark ListWitnesses(EmptyMessage) returns (WitnessList)

- (void)listWitnessesWithRequest:(EmptyMessage *)request handler:(void(^)(WitnessList *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToListWitnessesWithRequest:(EmptyMessage *)request handler:(void(^)(WitnessList *_Nullable response, NSError *_Nullable error))handler;


#pragma mark ListProposals(EmptyMessage) returns (ProposalList)

- (void)listProposalsWithRequest:(EmptyMessage *)request handler:(void(^)(ProposalList *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToListProposalsWithRequest:(EmptyMessage *)request handler:(void(^)(ProposalList *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetProposalById(BytesMessage) returns (Proposal)

- (void)getProposalByIdWithRequest:(BytesMessage *)request handler:(void(^)(Proposal *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetProposalByIdWithRequest:(BytesMessage *)request handler:(void(^)(Proposal *_Nullable response, NSError *_Nullable error))handler;


#pragma mark ListExchanges(EmptyMessage) returns (ExchangeList)

- (void)listExchangesWithRequest:(EmptyMessage *)request handler:(void(^)(ExchangeList *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToListExchangesWithRequest:(EmptyMessage *)request handler:(void(^)(ExchangeList *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetExchangeById(BytesMessage) returns (Exchange)

- (void)getExchangeByIdWithRequest:(BytesMessage *)request handler:(void(^)(Exchange *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetExchangeByIdWithRequest:(BytesMessage *)request handler:(void(^)(Exchange *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetChainParameters(EmptyMessage) returns (ChainParameters)

- (void)getChainParametersWithRequest:(EmptyMessage *)request handler:(void(^)(ChainParameters *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetChainParametersWithRequest:(EmptyMessage *)request handler:(void(^)(ChainParameters *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetAssetIssueList(EmptyMessage) returns (AssetIssueList)

- (void)getAssetIssueListWithRequest:(EmptyMessage *)request handler:(void(^)(AssetIssueList *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetAssetIssueListWithRequest:(EmptyMessage *)request handler:(void(^)(AssetIssueList *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetPaginatedAssetIssueList(PaginatedMessage) returns (AssetIssueList)

- (void)getPaginatedAssetIssueListWithRequest:(PaginatedMessage *)request handler:(void(^)(AssetIssueList *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetPaginatedAssetIssueListWithRequest:(PaginatedMessage *)request handler:(void(^)(AssetIssueList *_Nullable response, NSError *_Nullable error))handler;


#pragma mark TotalTransaction(EmptyMessage) returns (NumberMessage)

- (void)totalTransactionWithRequest:(EmptyMessage *)request handler:(void(^)(NumberMessage *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToTotalTransactionWithRequest:(EmptyMessage *)request handler:(void(^)(NumberMessage *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetNextMaintenanceTime(EmptyMessage) returns (NumberMessage)

- (void)getNextMaintenanceTimeWithRequest:(EmptyMessage *)request handler:(void(^)(NumberMessage *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetNextMaintenanceTimeWithRequest:(EmptyMessage *)request handler:(void(^)(NumberMessage *_Nullable response, NSError *_Nullable error))handler;

#pragma mark CreateAddress(BytesMessage) returns (BytesMessage)

/**
 * Warning: do not invoke this interface provided by others.
 */
- (void)createAddressWithRequest:(BytesMessage *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler;

/**
 * Warning: do not invoke this interface provided by others.
 */
- (GRPCProtoCall *)RPCToCreateAddressWithRequest:(BytesMessage *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler;

#pragma mark GetTransactionInfoById(BytesMessage) returns (TransactionInfo)

- (void)getTransactionInfoByIdWithRequest:(BytesMessage *)request handler:(void(^)(TransactionInfo *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetTransactionInfoByIdWithRequest:(BytesMessage *)request handler:(void(^)(TransactionInfo *_Nullable response, NSError *_Nullable error))handler;

#pragma mark GetDelegatedResource(Account) returns (DelegatedResourceAccountIndex)

- (void)getDelegatedResourceAccountWithRequest:(BytesMessage *)request handler:(void(^)(DelegatedResourceAccountIndex *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetDelegatedResourceAccountWithRequest:(BytesMessage *)request handler:(void(^)(DelegatedResourceAccountIndex *_Nullable response, NSError *_Nullable error))handler;

#pragma mark GetDelegatedResource(Account) returns (DelegatedResourceList)

- (void)getDelegatedResourceWithRequest:(DelegatedResourceMessage *)request handler:(void(^)(DelegatedResourceList *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetDelegatedResourceWithRequest:(DelegatedResourceMessage *)request handler:(void(^)(DelegatedResourceList *_Nullable response, NSError *_Nullable error))handler;

#pragma mark GetDelegatedResourceV2(Account) returns (DelegatedResourceAccountIndex)

- (void)getDelegatedResourceV2AccountWithRequest:(BytesMessage *)request handler:(void(^)(DelegatedResourceAccountIndex *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetDelegatedResourceV2AccountWithRequest:(BytesMessage *)request handler:(void(^)(DelegatedResourceAccountIndex *_Nullable response, NSError *_Nullable error))handler;

#pragma mark GetDelegatedResourceV2(Account) returns (DelegatedResourceList)

- (void)getDelegatedResourceV2WithRequest:(DelegatedResourceMessage *)request handler:(void(^)(DelegatedResourceList *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetDelegatedResourceV2WithRequest:(DelegatedResourceMessage *)request handler:(void(^)(DelegatedResourceList *_Nullable response, NSError *_Nullable error))handler;

#pragma mark AccountPermissionUpdate(AccountPermissionUpdateContract) returns (TransactionExtention)

- (void)accountPermissionUpdateWithRequest:(AccountPermissionUpdateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToAccountPermissionUpdateWithRequest:(AccountPermissionUpdateContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

#pragma mark GetTransactionApprovedList(Transaction) returns (TransactionApprovedList)

- (void)getTransactionApprovedListWithRequest:(TronTransaction *)request handler:(void(^)(TransactionApprovedList *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetTransactionApprovedListWithRequest:(TronTransaction *)request handler:(void(^)(TransactionApprovedList *_Nullable response, NSError *_Nullable error))handler;

#pragma mark GetTransactionSignWeight (Transaction) returns (TransactionSignWeight)

- (void)getTransactionSignWeightWithRequest:(TronTransaction *)request handler:(void(^)(TransactionSignWeight *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetTransactionSignWeightWithRequest:(TronTransaction *)request handler:(void(^)(TransactionSignWeight *_Nullable response, NSError *_Nullable error))handler;

#pragma mark GetRewardInfo (BytesMessage) returns (NumberMessage)

- (void)getRewardInfoWithRequest:(BytesMessage *)request handler:(void(^)(NumberMessage *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetRewardInfoWithRequest:(BytesMessage *)request handler:(void(^)(NumberMessage *_Nullable response, NSError *_Nullable error))handler;

#pragma mark GetBrokerageInfo (BytesMessage) returns (NumberMessage)

- (void)getBrokerageInfoWithRequest:(BytesMessage *)request handler:(void(^)(NumberMessage *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetBrokerageInfoWithRequest:(BytesMessage *)request handler:(void(^)(NumberMessage *_Nullable response, NSError *_Nullable error))handler;

#pragma mark UpdateBrokerage (UpdateBrokerageContract) returns (TransactionExtention)

- (void)updateBrokerageWithRequest:(UpdateBrokerageContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToUpdateBrokerageWithRequest:(UpdateBrokerageContract *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark CreateShieldedTransaction (PrivateParameters) returns (TransactionExtention)
- (void)createShieldedTransactionWithRequest:(PrivateParameters *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;
- (GRPCProtoCall *)RPCToCreateShieldedTransactionWithRequest:(PrivateParameters *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

#pragma mark GetMerkleTreeVoucherInfo (OutputPointInfo) returns (IncrementalMerkleVoucherInfo)
- (void)getMerkleTreeVoucherInfoWithRequest:(OutputPointInfo *)request handler:(void(^)(IncrementalMerkleVoucherInfo *_Nullable response, NSError *_Nullable error))handler;
- (GRPCProtoCall *)RPCToGetMerkleTreeVoucherInfoWithRequest:(OutputPointInfo *)request handler:(void(^)(IncrementalMerkleVoucherInfo *_Nullable response, NSError *_Nullable error))handler;

#pragma mark ScanNoteByIvk (IvkDecryptParameters) returns (DecryptNotes)
- (void)scanNoteByIvkWithRequest:(IvkDecryptParameters *)request handler:(void(^)(DecryptNotes *_Nullable response, NSError *_Nullable error))handler;
- (GRPCProtoCall *)RPCToScanNoteByIvkWithRequest:(IvkDecryptParameters *)request handler:(void(^)(DecryptNotes *_Nullable response, NSError *_Nullable error))handler;

#pragma mark ScanAndMarkNoteByIvk (IvkDecryptAndMarkParameters) returns (DecryptNotesMarked)
- (void)scanAndMarkNoteByIvkWithRequest:(IvkDecryptAndMarkParameters *)request handler:(void(^)(DecryptNotesMarked *_Nullable response, NSError *_Nullable error))handler;
- (GRPCProtoCall *)RPCToScanAndMarkNoteByIvkWithRequest:(IvkDecryptAndMarkParameters *)request handler:(void(^)(DecryptNotesMarked *_Nullable response, NSError *_Nullable error))handler;

#pragma mark ScanNoteByOvk (IvkDecryptParameters) returns (DecryptNotes)
- (void)scanNoteByOvkWithRequest:(OvkDecryptParameters *)request handler:(void(^)(DecryptNotes *_Nullable response, NSError *_Nullable error))handler;
- (GRPCProtoCall *)RPCToScanNoteByOvkWithRequest:(OvkDecryptParameters *)request handler:(void(^)(DecryptNotes *_Nullable response, NSError *_Nullable error))handler;

#pragma mark GetSpendingKey (EmptyMessage) returns (BytesMessage)
- (void)getSpendingKeyWithRequest:(EmptyMessage *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler;
- (GRPCProtoCall *)RPCToGetSpendingKeyWithRequest:(EmptyMessage *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler;

#pragma mark GetExpandedSpendingKey (BytesMessage) returns (ExpandedSpendingKeyMessage)
- (void)getExpandedSpendingKeyWithRequest:(BytesMessage *)request handler:(void(^)(ExpandedSpendingKeyMessage *_Nullable response, NSError *_Nullable error))handler;
- (GRPCProtoCall *)RPCToGetExpandedSpendingKeyWithRequest:(BytesMessage *)request handler:(void(^)(ExpandedSpendingKeyMessage *_Nullable response, NSError *_Nullable error))handler;

#pragma mark GetAkFromAsk (BytesMessage) returns (ExpandedSpendingKeyMessage)
- (void)getAkFromAskWithRequest:(BytesMessage *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler;
- (GRPCProtoCall *)RPCToGetAkFromAskWithRequest:(BytesMessage *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler;

#pragma mark GetNkFromNsk (BytesMessage) returns (ExpandedSpendingKeyMessage)
- (void)getNkFromNskWithRequest:(BytesMessage *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetNkFromNskWithRequest:(BytesMessage *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler;

#pragma mark GetIncomingViewingKey (ViewingKeyMessage) returns (ExpandedSpendingKeyMessage)
- (void)getIncomingViewingKeyWithRequest:(ViewingKeyMessage *)request handler:(void(^)(IncomingViewingKeyMessage *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetIncomingViewingKeyWithRequest:(ViewingKeyMessage *)request handler:(void(^)(IncomingViewingKeyMessage *_Nullable response, NSError *_Nullable error))handler;

#pragma mark GetDiversifier (EmptyMessage) returns (DiversifierMessage)
- (void)getDiversifierWithRequest:(EmptyMessage *)request handler:(void(^)(DiversifierMessage *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetDiversifierWithRequest:(EmptyMessage *)request handler:(void(^)(DiversifierMessage *_Nullable response, NSError *_Nullable error))handler;

#pragma mark GetZenPaymentAddress (IncomingViewingKeyDiversifierMessage) returns (PaymentAddressMessage)
- (void)getZenPaymentAddressWithRequest:(IncomingViewingKeyDiversifierMessage *)request handler:(void(^)(PaymentAddressMessage *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetZenPaymentAddressWithRequest:(IncomingViewingKeyDiversifierMessage *)request handler:(void(^)(PaymentAddressMessage *_Nullable response, NSError *_Nullable error))handler;

#pragma mark GetRcm (EmptyMessage) returns (BytesMessage)
- (void)getRcmWithRequest:(EmptyMessage *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler;
- (GRPCProtoCall *)RPCToGetRcmWithRequest:(EmptyMessage *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler;

#pragma mark IsSpend (NoteParameters) returns (BytesMessage)
- (void)isSpendWithRequest:(NoteParameters *)request handler:(void(^)(SpendResult *_Nullable response, NSError *_Nullable error))handler;
- (GRPCProtoCall *)RPCToIsSpendWithRequest:(NoteParameters *)request handler:(void(^)(SpendResult *_Nullable response, NSError *_Nullable error))handler;

#pragma mark CreateShieldedTransactionWithoutSpendAuthSig (PrivateParametersWithoutAsk) returns (TransactionExtention)
- (void)createShieldedTransactionWithoutSpendAuthSigWithRequest:(PrivateParametersWithoutAsk *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToCreateShieldedTransactionWithoutSpendAuthSigWithRequest:(PrivateParametersWithoutAsk *)request handler:(void(^)(TransactionExtention *_Nullable response, NSError *_Nullable error))handler;

#pragma mark GetShieldTransactionHash (TronTransaction) returns (BytesMessage)
- (void)getShieldTransactionHashWithRequest:(TronTransaction *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetShieldTransactionHashWithRequest:(TronTransaction *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler;

#pragma mark CreateSpendAuthSig (SpendAuthSigParameters) returns (BytesMessage)
- (void)createSpendAuthSigWithRequest:(SpendAuthSigParameters *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler;
- (GRPCProtoCall *)RPCToCreateSpendAuthSigWithRequest:(SpendAuthSigParameters *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler;

#pragma mark CreateShieldNullifier (NfParameters) returns (BytesMessage)
- (void)createShieldNullifierWithRequest:(NfParameters *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler;
- (GRPCProtoCall *)RPCToCreateShieldNullifierWithRequest:(NfParameters *)request handler:(void(^)(BytesMessage *_Nullable response, NSError *_Nullable error))handler;

@end

@protocol WalletSolidity <NSObject>

#pragma mark GetAccount(Account) returns (Account)

- (void)getAccountWithRequest:(TronAccount *)request handler:(void(^)(TronAccount *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetAccountWithRequest:(TronAccount *)request handler:(void(^)(TronAccount *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetAccountById(Account) returns (Account)

- (void)getAccountByIdWithRequest:(TronAccount *)request handler:(void(^)(TronAccount *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetAccountByIdWithRequest:(TronAccount *)request handler:(void(^)(TronAccount *_Nullable response, NSError *_Nullable error))handler;


#pragma mark ListWitnesses(EmptyMessage) returns (WitnessList)

- (void)listWitnessesWithRequest:(EmptyMessage *)request handler:(void(^)(WitnessList *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToListWitnessesWithRequest:(EmptyMessage *)request handler:(void(^)(WitnessList *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetAssetIssueList(EmptyMessage) returns (AssetIssueList)

- (void)getAssetIssueListWithRequest:(EmptyMessage *)request handler:(void(^)(AssetIssueList *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetAssetIssueListWithRequest:(EmptyMessage *)request handler:(void(^)(AssetIssueList *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetPaginatedAssetIssueList(PaginatedMessage) returns (AssetIssueList)

- (void)getPaginatedAssetIssueListWithRequest:(PaginatedMessage *)request handler:(void(^)(AssetIssueList *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetPaginatedAssetIssueListWithRequest:(PaginatedMessage *)request handler:(void(^)(AssetIssueList *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetNowBlock(EmptyMessage) returns (Block)

/**
 * Please use GetNowBlock2 instead of this function.
 */
- (void)getNowBlockWithRequest:(EmptyMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler;

/**
 * Please use GetNowBlock2 instead of this function.
 */
- (GRPCProtoCall *)RPCToGetNowBlockWithRequest:(EmptyMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetNowBlock2(EmptyMessage) returns (BlockExtention)

/**
 * Use this function instead of GetNowBlock.
 */
- (void)getNowBlock2WithRequest:(EmptyMessage *)request handler:(void(^)(BlockExtention *_Nullable response, NSError *_Nullable error))handler;

/**
 * Use this function instead of GetNowBlock.
 */
- (GRPCProtoCall *)RPCToGetNowBlock2WithRequest:(EmptyMessage *)request handler:(void(^)(BlockExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetBlockByNum(NumberMessage) returns (Block)

/**
 * Please use GetBlockByNum2 instead of this function.
 */
- (void)getBlockByNumWithRequest:(NumberMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler;

/**
 * Please use GetBlockByNum2 instead of this function.
 */
- (GRPCProtoCall *)RPCToGetBlockByNumWithRequest:(NumberMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetBlockByNum2(NumberMessage) returns (BlockExtention)

/**
 * Use this function instead of GetBlockByNum.
 */
- (void)getBlockByNum2WithRequest:(NumberMessage *)request handler:(void(^)(BlockExtention *_Nullable response, NSError *_Nullable error))handler;

/**
 * Use this function instead of GetBlockByNum.
 */
- (GRPCProtoCall *)RPCToGetBlockByNum2WithRequest:(NumberMessage *)request handler:(void(^)(BlockExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetTransactionCountByBlockNum(NumberMessage) returns (NumberMessage)

- (void)getTransactionCountByBlockNumWithRequest:(NumberMessage *)request handler:(void(^)(NumberMessage *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetTransactionCountByBlockNumWithRequest:(NumberMessage *)request handler:(void(^)(NumberMessage *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetTransactionById(BytesMessage) returns (Transaction)

- (void)getTransactionByIdWithRequest:(BytesMessage *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetTransactionByIdWithRequest:(BytesMessage *)request handler:(void(^)(TronTransaction *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetTransactionInfoById(BytesMessage) returns (TransactionInfo)

- (void)getTransactionInfoByIdWithRequest:(BytesMessage *)request handler:(void(^)(TransactionInfo *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetTransactionInfoByIdWithRequest:(BytesMessage *)request handler:(void(^)(TransactionInfo *_Nullable response, NSError *_Nullable error))handler;

@end

@protocol WalletExtension <NSObject>

#pragma mark GetTransactionsFromThis(AccountPaginated) returns (TransactionList)

/**
 * Please use GetTransactionsFromThis2 instead of this function.
 */
- (void)getTransactionsFromThisWithRequest:(AccountPaginated *)request handler:(void(^)(TransactionList *_Nullable response, NSError *_Nullable error))handler;

/**
 * Please use GetTransactionsFromThis2 instead of this function.
 */
- (GRPCProtoCall *)RPCToGetTransactionsFromThisWithRequest:(AccountPaginated *)request handler:(void(^)(TransactionList *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetTransactionsFromThis2(AccountPaginated) returns (TransactionListExtention)

/**
 * Use this function instead of GetTransactionsFromThis.
 */
- (void)getTransactionsFromThis2WithRequest:(AccountPaginated *)request handler:(void(^)(TransactionListExtention *_Nullable response, NSError *_Nullable error))handler;

/**
 * Use this function instead of GetTransactionsFromThis.
 */
- (GRPCProtoCall *)RPCToGetTransactionsFromThis2WithRequest:(AccountPaginated *)request handler:(void(^)(TransactionListExtention *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetTransactionsToThis(AccountPaginated) returns (TransactionList)

/**
 * Please use GetTransactionsToThis2 instead of this function.
 */
- (void)getTransactionsToThisWithRequest:(AccountPaginated *)request handler:(void(^)(TransactionList *_Nullable response, NSError *_Nullable error))handler;

/**
 * Please use GetTransactionsToThis2 instead of this function.
 */
- (GRPCProtoCall *)RPCToGetTransactionsToThisWithRequest:(AccountPaginated *)request handler:(void(^)(TransactionList *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetTransactionsToThis2(AccountPaginated) returns (TransactionListExtention)

/**
 * Use this function instead of GetTransactionsToThis.
 */
- (void)getTransactionsToThis2WithRequest:(AccountPaginated *)request handler:(void(^)(TransactionListExtention *_Nullable response, NSError *_Nullable error))handler;

/**
 * Use this function instead of GetTransactionsToThis.
 */
- (GRPCProtoCall *)RPCToGetTransactionsToThis2WithRequest:(AccountPaginated *)request handler:(void(^)(TransactionListExtention *_Nullable response, NSError *_Nullable error))handler;

@end

@protocol Database <NSObject>

#pragma mark getBlockReference(EmptyMessage) returns (BlockReference)

/**
 * for tapos
 */
- (void)getBlockReferenceWithRequest:(EmptyMessage *)request handler:(void(^)(BlockReference *_Nullable response, NSError *_Nullable error))handler;

/**
 * for tapos
 */
- (GRPCProtoCall *)RPCTogetBlockReferenceWithRequest:(EmptyMessage *)request handler:(void(^)(BlockReference *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetDynamicProperties(EmptyMessage) returns (DynamicProperties)

- (void)getDynamicPropertiesWithRequest:(EmptyMessage *)request handler:(void(^)(DynamicProperties *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetDynamicPropertiesWithRequest:(EmptyMessage *)request handler:(void(^)(DynamicProperties *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetNowBlock(EmptyMessage) returns (Block)

- (void)getNowBlockWithRequest:(EmptyMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetNowBlockWithRequest:(EmptyMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler;


#pragma mark GetBlockByNum(NumberMessage) returns (Block)

- (void)getBlockByNumWithRequest:(NumberMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler;

- (GRPCProtoCall *)RPCToGetBlockByNumWithRequest:(NumberMessage *)request handler:(void(^)(Block *_Nullable response, NSError *_Nullable error))handler;

@end

@protocol Network <NSObject>

@end


#if !defined(GPB_GRPC_PROTOCOL_ONLY) || !GPB_GRPC_PROTOCOL_ONLY
/**
 * Basic service implementation, over gRPC, that only does
 * marshalling and parsing.
 */
@interface TWallet : GRPCProtoService<TWallet>
- (instancetype)initWithHost:(NSString *)host NS_DESIGNATED_INITIALIZER;
+ (instancetype)serviceWithHost:(NSString *)host;
@end
/**
 * Basic service implementation, over gRPC, that only does
 * marshalling and parsing.
 */
@interface WalletSolidity : GRPCProtoService<WalletSolidity>
- (instancetype)initWithHost:(NSString *)host NS_DESIGNATED_INITIALIZER;
+ (instancetype)serviceWithHost:(NSString *)host;
@end
/**
 * Basic service implementation, over gRPC, that only does
 * marshalling and parsing.
 */
@interface WalletExtension : GRPCProtoService<WalletExtension>
- (instancetype)initWithHost:(NSString *)host NS_DESIGNATED_INITIALIZER;
+ (instancetype)serviceWithHost:(NSString *)host;
@end
/**
 * Basic service implementation, over gRPC, that only does
 * marshalling and parsing.
 */
@interface Database : GRPCProtoService<Database>
- (instancetype)initWithHost:(NSString *)host NS_DESIGNATED_INITIALIZER;
+ (instancetype)serviceWithHost:(NSString *)host;
@end
/**
 * Basic service implementation, over gRPC, that only does
 * marshalling and parsing.
 */
@interface Network : GRPCProtoService<Network>
- (instancetype)initWithHost:(NSString *)host NS_DESIGNATED_INITIALIZER;
+ (instancetype)serviceWithHost:(NSString *)host;
@end
#endif

NS_ASSUME_NONNULL_END

