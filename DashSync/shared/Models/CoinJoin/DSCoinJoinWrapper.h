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

#import <Foundation/Foundation.h>
#import "DSChain.h"
#import "DSTransactionOutput.h"
#import "DSCoinControl.h"
#import "DSCompactTallyItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSCoinJoinWrapper : NSObject

// TODO: free on dealloc
@property (strong, nonatomic, readonly) DSChain *chain;
@property (nonatomic, assign, nullable) CoinJoinClientSession *clientSession;
@property (nonatomic, assign, nullable) CoinJoinClientOptions *options;

@property (nonatomic, assign) BOOL anonymizableTallyCachedNonDenom;
@property (nonatomic, assign) BOOL anonymizableTallyCached;

- (instancetype)initWithChain:(DSChain *)chain;

- (BOOL)isMineInput:(UInt256)txHash index:(uint32_t)index;
- (BOOL)hasCollateralInputs:(WalletEx *)walletEx onlyConfirmed:(BOOL)onlyConfirmed;
- (NSArray<DSTransactionOutput *> *) availableCoins:(WalletEx *)walletEx onlySafe:(BOOL)onlySafe coinControl:(DSCoinControl *_Nullable)coinControl minimumAmount:(uint64_t)minimumAmount maximumAmount:(uint64_t)maximumAmount minimumSumAmount:(uint64_t)minimumSumAmount maximumCount:(uint64_t)maximumCount;
- (NSArray<DSCompactTallyItem *> *)selectCoinsGroupedByAddresses:(WalletEx *)walletEx skipDenominated:(BOOL)skipDenominated anonymizable:(BOOL)anonymizable skipUnconfirmed:(BOOL)skipUnconfirmed maxOupointsPerAddress:(int32_t)maxOupointsPerAddress;
- (uint32_t)countInputsWithAmount:(uint64_t)inputAmount;

@end

NS_ASSUME_NONNULL_END
