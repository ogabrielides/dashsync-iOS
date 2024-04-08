//
//  Created by Andrei Ashikhmin
//  Copyright © 2024 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DSCoinJoinManager.h"
#import "DSWallet.h"
#import "DSTransaction+CoinJoin.h"
#import "DSTransactionOutput+CoinJoin.h"
#import "DSSimplifiedMasternodeEntry+Mndiff.h"
#import "DSMasternodeList+Mndiff.h"
#import "DSAccount.h"
#import "DSChainManager.h"
#import "DSCoinJoinWrapper.h"

#define AS_OBJC(context) ((__bridge DSCoinJoinWrapper *)(context))
#define AS_RUST(context) ((__bridge void *)(context))

@implementation DSCoinJoinManager

- (instancetype)initWithChainManager:(DSChainManager *)chainManager {
    self = [super init];
    if (self) {
        _chainManager = chainManager;
        _wrapper = [[DSCoinJoinWrapper alloc] initWithManagers:self.chainManager coinJoinManager:self];
        _masternodeGroup = [[DSMasternodeGroup alloc] init];
        _wrapper.masternodeGroup = _masternodeGroup;
    }
    return self;
}

- (void)runCoinJoin {
    if (_options != NULL) {
        free(_options);
        _options = NULL;
    }
    
    _options = [self createOptions];
    
    DSLog(@"[OBJ-C] CoinJoin: register");
    _walletEx = register_wallet_ex(AS_RUST(self.wrapper), _options, getTransaction, signTransaction, destroyTransaction, isMineInput, commitTransaction, masternodeByHash, destroyMasternodeEntry, validMNCount, isBlockchainSynced, freshCoinJoinAddress, countInputsWithAmount, availableCoins, destroyGatheredOutputs, selectCoinsGroupedByAddresses, destroySelectedCoins, isMasternodeOrDisconnectRequested);
    _clientManager = register_client_manager(AS_RUST(self.wrapper), _walletEx, _options, getMNList, destroyMNList, getInputValueByPrevoutHash, hasChainLock, destroyInputValue);
    
    DSLog(@"[OBJ-C] CoinJoin: call");
    Balance *balance = [self getBalance];
    
    run_client_manager(_clientManager, *balance);
//    DSLog(@"[OBJ-C] CoinJoin: do_automatic_denominating result: %llu", self.wrapper.balance_needs_anonymized);
//    free(balance);
}

- (CoinJoinClientOptions *)createOptions {
    CoinJoinClientOptions *options = malloc(sizeof(CoinJoinClientOptions));
    options->enable_coinjoin = YES;
    options->coinjoin_rounds = 1;
    options->coinjoin_sessions = 1;
    options->coinjoin_amount = DUFFS / 4; // 0.25 DASH
    options->coinjoin_random_rounds = COINJOIN_RANDOM_ROUNDS;
    options->coinjoin_denoms_goal = DEFAULT_COINJOIN_DENOMS_GOAL;
    options->coinjoin_denoms_hardcap = DEFAULT_COINJOIN_DENOMS_HARDCAP;
    options->coinjoin_multi_session = NO;
    DSLog(@"[OBJ-C] CoinJoin: trusted balance: %llu", self.wrapper.chain.balance);
    
    return options;
}

-(Balance *)getBalance {
    Balance *balance = malloc(sizeof(Balance));
    balance->my_trusted = self.wrapper.chain.balance;
    balance->my_immature = 0;
    balance->anonymized = 0;
    balance->my_untrusted_pending = 0;
    balance->denominated_trusted = 0;
    balance->denominated_untrusted_pending = 0;
    balance->watch_only_trusted = 0;
    balance->watch_only_untrusted_pending = 0;
    balance->watch_only_immature = 0;
    
    return balance;
}

- (void)dealloc {
    if (_options != NULL) {
        free(_options);
    }
    
    unregister_client_manager(_clientManager);
    unregister_wallet_ex(_walletEx); // Unregister last
}

///
/// MARK: Rust FFI callbacks
///

InputValue *getInputValueByPrevoutHash(uint8_t (*prevout_hash)[32], uint32_t index, const void *context) {
    UInt256 txHash = *((UInt256 *)prevout_hash);
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: getInputValueByPrevoutHash");
    InputValue *inputValue = NULL;
    
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        inputValue = malloc(sizeof(InputValue));
        DSWallet *wallet = wrapper.chain.wallets.firstObject;
        int64_t value = [wallet inputValue:txHash inputIndex:index];
            
        if (value != -1) {
            inputValue->is_valid = TRUE;
            inputValue->value = value;
        } else {
            inputValue->is_valid = FALSE;
        }
    }
    
    processor_destroy_block_hash(prevout_hash);
    return inputValue;
}


bool hasChainLock(Block *block, const void *context) {
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: hasChainLock");
    BOOL hasChainLock = NO;
    
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        hasChainLock = [wrapper.chain blockHeightChainLocked:block->height];
    }
    
    processor_destroy_block(block);
    return hasChainLock;
}

Transaction *getTransaction(uint8_t (*tx_hash)[32], const void *context) {
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: getTransaction");
    UInt256 txHash = *((UInt256 *)tx_hash);
    Transaction *tx = NULL;
    
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        DSTransaction *transaction = [wrapper.chain transactionForHash:txHash];

        if (transaction) {
            tx = [transaction ffi_malloc:wrapper.chain.chainType];
        }
    }
    
    processor_destroy_block_hash(tx_hash);
    return tx;
}

bool isMineInput(uint8_t (*tx_hash)[32], uint32_t index, const void *context) {
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: isMine");
    UInt256 txHash = *((UInt256 *)tx_hash);
    BOOL result = NO;
    
    @synchronized (context) {
        result = [AS_OBJC(context) isMineInput:txHash index:index];
    }
    
    processor_destroy_block_hash(tx_hash);
    return result;
}

GatheredOutputs* availableCoins(bool onlySafe, CoinControl coinControl, WalletEx *walletEx, const void *context) {
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: hasCollateralInputs");
    GatheredOutputs *gatheredOutputs;
    
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        ChainType chainType = wrapper.chain.chainType;
        DSCoinControl *cc = [[DSCoinControl alloc] initWithFFICoinControl:&coinControl];
        NSArray<DSInputCoin *> *coins = [wrapper availableCoins:walletEx onlySafe:onlySafe coinControl:cc minimumAmount:1 maximumAmount:MAX_MONEY minimumSumAmount:MAX_MONEY maximumCount:0];
        
        gatheredOutputs = malloc(sizeof(GatheredOutputs));
        InputCoin **coinsArray = malloc(coins.count * sizeof(InputCoin *));
        
        for (uintptr_t i = 0; i < coins.count; ++i) {
            coinsArray[i] = [coins[i] ffi_malloc:chainType];
        }
        
        gatheredOutputs->items = coinsArray;
        gatheredOutputs->item_count = (uintptr_t)coins.count;
    }
    
    return gatheredOutputs;
}

SelectedCoins* selectCoinsGroupedByAddresses(bool skipDenominated, bool anonymizable, bool skipUnconfirmed, int maxOupointsPerAddress, WalletEx* walletEx, const void *context) {
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: selectCoinsGroupedByAddresses");
    SelectedCoins *vecTallyRet;
    
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        NSArray<DSCompactTallyItem *> *tempVecTallyRet = [wrapper selectCoinsGroupedByAddresses:walletEx skipDenominated:skipDenominated anonymizable:anonymizable skipUnconfirmed:skipUnconfirmed maxOupointsPerAddress:maxOupointsPerAddress];
        
        vecTallyRet = malloc(sizeof(SelectedCoins));
        vecTallyRet->item_count = tempVecTallyRet.count;
        vecTallyRet->items = malloc(tempVecTallyRet.count * sizeof(CompactTallyItem *));
        
        for (uint32_t i = 0; i < tempVecTallyRet.count; i++) {
            vecTallyRet->items[i] = [tempVecTallyRet[i] ffi_malloc:wrapper.chain.chainType];
        }
    }
    
    return vecTallyRet;
}

void destroyInputValue(InputValue *value) {
    DSLog(@"[OBJ-C] CoinJoin: 💀 InputValue");
    
    if (value) {
        free(value);
    }
}

void destroyTransaction(Transaction *value) {
    if (value) {
        [DSTransaction ffi_free:value];
    }
}

void destroySelectedCoins(SelectedCoins *selectedCoins) {
    if (!selectedCoins) {
        return;
    }
    
    DSLog(@"[OBJ-C] CoinJoin: 💀 SelectedCoins");
    
    if (selectedCoins->item_count > 0 && selectedCoins->items) {
        for (int i = 0; i < selectedCoins->item_count; i++) {
            [DSCompactTallyItem ffi_free:selectedCoins->items[i]];
        }
        
        free(selectedCoins->items);
    }
    
    free(selectedCoins);
}

void destroyGatheredOutputs(GatheredOutputs *gatheredOutputs) {
    if (!gatheredOutputs) {
        return;
    }
    
    DSLog(@"[OBJ-C] CoinJoin: 💀 GatheredOutputs");
    
    if (gatheredOutputs->item_count > 0 && gatheredOutputs->items) {
        for (int i = 0; i < gatheredOutputs->item_count; i++) {
            [DSTransactionOutput ffi_free:gatheredOutputs->items[i]->output];
            free(gatheredOutputs->items[i]->outpoint_hash);
        }
        
        free(gatheredOutputs->items);
    }
    
    free(gatheredOutputs);
}

Transaction* signTransaction(Transaction *transaction, const void *context) {
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: signTransaction");
    
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        DSTransaction *tx = [[DSTransaction alloc] initWithTransaction:transaction onChain:wrapper.chain];
        destroy_transaction(transaction);
        
        BOOL isSigned = [wrapper.chain.wallets.firstObject.accounts.firstObject signTransaction:tx];
        
        if (isSigned) {
            return [tx ffi_malloc:wrapper.chain.chainType];
        }
    }
    
    return nil;
}

unsigned int countInputsWithAmount(unsigned long long inputAmount, const void *context) {
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: countInputsWithAmount");
    return [AS_OBJC(context) countInputsWithAmount:inputAmount];
}

ByteArray freshCoinJoinAddress(bool internal, const void *context) {
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: freshCoinJoinAddress");
    DSCoinJoinWrapper *wrapper = AS_OBJC(context);
    NSString *address = [wrapper freshAddress:internal];
    
    return script_pubkey_for_address([address UTF8String], wrapper.chain.chainType);
}

bool commitTransaction(struct Recipient **items, uintptr_t item_count, const void *context) {
    DSLog(@"[OBJ-C] CoinJoin: commitTransaction");
    
    NSMutableArray *amounts = [NSMutableArray array];
    NSMutableArray *scripts = [NSMutableArray array];
    
    for (uintptr_t i = 0; i < item_count; i++) {
        Recipient *recipient = items[i];
        [amounts addObject:@(recipient->amount)];
        NSData *script = [NSData dataWithBytes:recipient->script_pub_key.ptr length:recipient->script_pub_key.len];
        [scripts addObject:script];
    }
    
    // TODO: check subtract_fee_from_amount
    bool result = false;
    
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        result = [wrapper commitTransactionForAmounts:amounts outputs:scripts onPublished:^(NSError * _Nullable error) {
            if (!error) {
                // TODO: let balance_denominated_unconf = balance_info.denominated_untrusted_pending;
                uint64_t balanceDenominatedUnconf = 0;
                DSLog(@"[OBJ-C] CoinJoin: call finish_automatic_denominating");
                bool isFinished = finish_automatic_denominating(wrapper.manager.clientManager, balanceDenominatedUnconf, wrapper.balance_needs_anonymized);
                DSLog(@"[OBJ-C] CoinJoin: is automatic_denominating finished: %s", isFinished ? "YES" : "NO");
            }
        }];
    }
    
    return result;
}

MasternodeEntry* masternodeByHash(uint8_t (*hash)[32], const void *context) {
    UInt256 mnHash = *((UInt256 *)hash);
    MasternodeEntry *masternode;
    
    @synchronized (context) {
        masternode = [[AS_OBJC(context) masternodeEntryByHash:mnHash] ffi_malloc];
    }
    
    return masternode;
}

void destroyMasternodeEntry(MasternodeEntry *masternodeEntry) {
    if (!masternodeEntry) {
        return;
    }
    
    DSLog(@"[OBJ-C] CoinJoin: 💀 MasternodeEntry");
    [DSSimplifiedMasternodeEntry ffi_free:masternodeEntry];
}

uint64_t validMNCount(const void *context) {
    uint64_t result = 0;
    
    @synchronized (context) {
        result = [AS_OBJC(context) validMNCount];
    }
    
    return result;
}

MasternodeList* getMNList(const void *context) {
    MasternodeList *masternodes;
    
    @synchronized (context) {
        masternodes = [[AS_OBJC(context) mnList] ffi_malloc];
    }
    
    return masternodes;
}

void destroyMNList(MasternodeList *masternodeList) { // TODO: check destroyMasternodeList
    if (!masternodeList) {
        return;
    }
    
    DSLog(@"[OBJ-C] CoinJoin: 💀 MasternodeList");
    [DSMasternodeList ffi_free:masternodeList];
}

bool isBlockchainSynced(const void *context) {
    BOOL result = NO;
    
    @synchronized (context) {
        result = AS_OBJC(context).chainManager.combinedSyncProgress == 1.0;
    }
    
    return result;
}

bool isMasternodeOrDisconnectRequested(uint8_t (*ip_address)[16], uint16_t port, const void *context) {
    BOOL result = NO;
    
    @synchronized (context) {
        // TODO: ip_address, port
        result = AS_OBJC(context).isMasternodeOrDisconnectRequested;
    }
    
    return result;
}

@end
