//
//  Created by Vladimir Pirogov
//  Copyright © 2021 Dash Core Group. All rights reserved.
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

#import "DSChain.h"
#import "DSMasternodeProcessorContext.h"
#import "DSMasternodeList.h"
#import "DSMasternodeManager.h"
#import "DSMnDiffProcessingResult.h"
#import "DSQRInfoProcessingResult.h"
#import "DSQuorumEntry.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "dash_shared_core.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSMasternodeManager (Mndiff)

const MasternodeList *getMasternodeListByBlockHash(uint8_t (*block_hash)[32], const void *context);
void destroyMasternodeList(const MasternodeList *masternode_list);
uint32_t getBlockHeightByHash(uint8_t (*block_hash)[32], const void *context);
uint8_t *getBlockHashByHeight(uint32_t block_height, const void *context);
const LLMQSnapshot *getLLMQSnapshotByBlockHash(uint8_t (*block_hash)[32], const void *context);
void addInsightForBlockHash(uint8_t (*block_hash)[32], const void *context);
bool shouldProcessLLMQType(uint8_t quorum_type, const void *context);
bool validateLLMQ(struct LLMQValidationData *data, const void *context);
void destroyHash(uint8_t (*block_hash)[32]);

+ (MasternodeProcessor *)registerProcessor;
+ (void)unregisterProcessor:(MasternodeProcessor *)processor;

+ (MasternodeProcessorCache *)createProcessorCache;
+ (void)destroyProcessorCache:(MasternodeProcessorCache *)processorCache;

- (DSMnDiffProcessingResult *)processMasternodeDiffMessage:(NSData *)message withContext:(DSMasternodeProcessorContext *)context;

+ (QRInfo *)readQRInfoMessage:(NSData *)message
                  withContext:(DSMasternodeProcessorContext *)context
                withProcessor:(MasternodeProcessor *)processor;

+ (void)destroyQRInfoMessage:(QRInfo *)info;

- (DSQRInfoProcessingResult *)processQRInfo:(QRInfo *)info withContext:(DSMasternodeProcessorContext *)context;

@end


NS_ASSUME_NONNULL_END
