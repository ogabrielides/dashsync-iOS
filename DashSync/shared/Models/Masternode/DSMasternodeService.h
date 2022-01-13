//  
//  Created by Vladimir Pirogov
//  Copyright © 2022 Dash Core Group. All rights reserved.
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
#import "DSInsightManager.h"
#import "DSPeer.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSMasternodeService : NSObject

@property (nonatomic, readonly, nonnull) DSChain *chain;
@property (nonatomic, readonly) NSMutableSet<NSData *> *masternodeListsInRetrieval;
@property (nonatomic, readonly) NSMutableOrderedSet<NSData *> *masternodeListRetrievalQueue;
@property (nonatomic, readonly) NSUInteger masternodeListRetrievalQueueCount;
@property (nonatomic, readonly) NSUInteger masternodeListRetrievalQueueMaxAmount;

- (instancetype)initWithChain:(DSChain *)chain blockHeightLookup:(BlockHeightFinder)blockHeightLookup;
- (void)addToMasternodeRetrievalQueue:(NSData *)masternodeBlockHashData;
- (void)addToMasternodeRetrievalQueueArray:(NSArray *)masternodeBlockHashDataArray;
- (void)blockUntilAddInsight:(UInt256)entryQuorumHash;
- (void)cleanAllLists;
- (void)cleanListsInRetrieval;
- (void)cleanListsRetrievalQueue;
- (void)fetchMasternodeListsToRetrieve:(void (^)(NSOrderedSet<NSData *> *listsToRetrieve))completion;
- (BOOL)removeListInRetrievalForKey:(NSData *)blockHashDiffsData;

- (void)disconnectFromDownloadPeer;
- (void)issueWithMasternodeListFromPeer:(DSPeer *)peer;
- (void)requestMasternodeListDiff:(UInt256)previousBlockHash forBlockHash:(UInt256)blockHash;
- (void)requestQuorumRotationInfo:(UInt256)previousBlockHash forBlockHash:(UInt256)blockHash extraShare:(BOOL)extraShare;

@end

NS_ASSUME_NONNULL_END
