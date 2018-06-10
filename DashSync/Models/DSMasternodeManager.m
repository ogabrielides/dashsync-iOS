//
//  DSMasternodeManager.m
//  DashSync
//
//  Created by Sam Westrich on 6/7/18.
//

#import "DSMasternodeManager.h"
#import "DSMasternodeBroadcast.h"
#import "DSMasternodePing.h"
#import "DSMasternodeBroadcastEntity+CoreDataProperties.h"
#import "DSMasternodeBroadcastHashEntity+CoreDataProperties.h"
#import "NSManagedObject+Sugar.h"
#import "DSChain.h"
#import "DSPeer.h"
#import "NSData+Dash.h"

#define REQUEST_MASTERNODE_BROADCAST_COUNT 500

@interface DSMasternodeManager()

@property (nonatomic,strong) DSChain * chain;
@property (nonatomic,strong) NSOrderedSet * knownHashes;
@property (nonatomic,readonly) NSOrderedSet * fulfilledRequestsHashEntities;
@property (nonatomic,strong) NSMutableArray *needsRequestsHashEntities;
@property (nonatomic,strong) NSMutableArray * requestHashEntities;
@property (nonatomic,strong) NSMutableArray<DSMasternodeBroadcast *> * masternodeBroadcasts;
@property (nonatomic,assign) NSUInteger masternodeBroadcastsCount;
@property (nonatomic,strong) NSMutableDictionary * masternodeSyncCountInfo;
@property (nonatomic,strong) NSManagedObjectContext * managedObjectContext;

@end

@implementation DSMasternodeManager

- (instancetype)initWithChain:(id)chain
{
    if (! (self = [super init])) return nil;
    _chain = chain;
    _masternodeBroadcasts = [NSMutableArray array];
    self.masternodeSyncCountInfo = [NSMutableDictionary dictionary];
    self.managedObjectContext = [NSManagedObject context];
    return self;
}

//-(NSArray*)masternodeHashes {
//
//}

-(NSUInteger)recentMasternodeBroadcastHashesCount {
    __block NSUInteger count = 0;
    [self.managedObjectContext performBlockAndWait:^{
        count = [DSMasternodeBroadcastHashEntity countAroundNowOnChain:self.chain.chainEntity];
    }];
    return count;
}

-(NSUInteger)last3HoursStandaloneBroadcastHashesCount {
    __block NSUInteger count = 0;
    [self.managedObjectContext performBlockAndWait:^{
        [DSMasternodeBroadcastHashEntity setContext:self.managedObjectContext];
        count = [DSMasternodeBroadcastHashEntity standaloneCountInLast3hoursOnChain:self.chain.chainEntity];
    }];
    return count;
}

-(NSUInteger)masternodeBroadcastsCount {
    
    __block NSUInteger count = 0;
    [self.managedObjectContext performBlockAndWait:^{
        [DSMasternodeBroadcastEntity setContext:self.managedObjectContext];
        count = [DSMasternodeBroadcastEntity countForChain:self.chain.chainEntity];
    }];
    return count;
}


-(void)loadMasternodes:(NSUInteger)count {
    NSFetchRequest * fetchRequest = [[DSMasternodeBroadcastEntity fetchRequest] copy];
    [fetchRequest setFetchLimit:count];
    NSArray * masternodeBroadcastEntities = [DSMasternodeBroadcastEntity fetchObjects:fetchRequest];
    for (DSMasternodeBroadcastEntity * masternodeBroadcastEntity in masternodeBroadcastEntities) {
        DSUTXO utxo;
        utxo.hash = *(UInt256 *)masternodeBroadcastEntity.utxoHash.bytes;
        utxo.n = masternodeBroadcastEntity.utxoIndex;
        UInt128 ipv6address = UINT128_ZERO;
        ipv6address.u32[3] = masternodeBroadcastEntity.address;
        UInt256 masternodeBroadcastHash = *(UInt256 *)masternodeBroadcastEntity.masternodeBroadcastHash.masternodeBroadcastHash.bytes;
        DSMasternodeBroadcast * masternodeBroadcast = [[DSMasternodeBroadcast alloc] initWithUTXO:utxo ipAddress:ipv6address port:masternodeBroadcastEntity.port protocolVersion:masternodeBroadcastEntity.protocolVersion publicKey:masternodeBroadcastEntity.publicKey signature:masternodeBroadcastEntity.signature signatureTimestamp:masternodeBroadcastEntity.signatureTimestamp masternodeBroadcastHash:masternodeBroadcastHash onChain:self.chain];
        [_masternodeBroadcasts addObject:masternodeBroadcast];
    }
}

-(NSOrderedSet*)knownHashes {
    if (_knownHashes) return _knownHashes;
    
    [self.managedObjectContext performBlockAndWait:^{
        [DSMasternodeBroadcastHashEntity setContext:self.managedObjectContext];
        NSFetchRequest *request = DSMasternodeBroadcastHashEntity.fetchReq;
        [request setPredicate:[NSPredicate predicateWithFormat:@"chain = %@",self.chain.chainEntity]];
        [request setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"masternodeBroadcastHash" ascending:TRUE]]];
        NSArray<DSMasternodeBroadcastHashEntity *> * knownMasternodeBroadcastHashEntities = [DSMasternodeBroadcastHashEntity fetchObjects:request];
        NSMutableOrderedSet <NSData*> * rHashes = [NSMutableOrderedSet orderedSetWithCapacity:knownMasternodeBroadcastHashEntities.count];
        for (DSMasternodeBroadcastHashEntity * knownMasternodeBroadcastHashEntity in knownMasternodeBroadcastHashEntities) {
            NSData * hash = knownMasternodeBroadcastHashEntity.masternodeBroadcastHash;
            [rHashes addObject:hash];
        }
        self.knownHashes = [rHashes copy];
    }];
    return _knownHashes;
}

-(NSMutableArray*)needsRequestsHashEntities {
    if (_needsRequestsHashEntities) return _needsRequestsHashEntities;
    
    [self.managedObjectContext performBlockAndWait:^{
        [DSMasternodeBroadcastHashEntity setContext:self.managedObjectContext];
        NSFetchRequest *request = DSMasternodeBroadcastHashEntity.fetchReq;
        [request setPredicate:[NSPredicate predicateWithFormat:@"chain = %@ && masternodeBroadcast == nil",self.chain.chainEntity]];
        [request setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"masternodeBroadcastHash" ascending:TRUE]]];
        self.needsRequestsHashEntities = [[DSMasternodeBroadcastHashEntity fetchObjects:request] mutableCopy];

    }];
    return _needsRequestsHashEntities;
}

-(NSArray*)needsRequestsHashes {
    __block NSMutableArray * mArray = [NSMutableArray array];
    [self.managedObjectContext performBlockAndWait:^{
        [DSMasternodeBroadcastHashEntity setContext:self.managedObjectContext];
        for (DSMasternodeBroadcastHashEntity * masternodeBroadcastHashEntity in self.needsRequestsHashEntities) {
            [mArray addObject:masternodeBroadcastHashEntity.masternodeBroadcastHash];
        }
    }];
    return [mArray copy];
}

-(NSOrderedSet*)fulfilledRequestsHashEntities {
    __block NSOrderedSet * orderedSet;
    [self.managedObjectContext performBlockAndWait:^{
        [DSMasternodeBroadcastHashEntity setContext:self.managedObjectContext];
        NSFetchRequest *request = DSMasternodeBroadcastHashEntity.fetchReq;
        [request setPredicate:[NSPredicate predicateWithFormat:@"chain = %@ && masternodeBroadcast != nil",self.chain.chainEntity]];
        [request setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"masternodeBroadcastHash" ascending:TRUE]]];
        orderedSet = [NSOrderedSet orderedSetWithArray:[DSMasternodeBroadcastHashEntity fetchObjects:request]];
        
    }];
    return orderedSet;
}

-(NSOrderedSet*)fulfilledRequestsHashes {
    NSMutableOrderedSet * mOrderedSet = [NSMutableOrderedSet orderedSet];
    for (DSMasternodeBroadcastHashEntity * masternodeBroadcastHashEntity in self.fulfilledRequestsHashEntities) {
        [mOrderedSet addObject:masternodeBroadcastHashEntity.masternodeBroadcastHash];
    }
    return [mOrderedSet copy];
}

-(void)requestMasternodeBroadcastsFromPeer:(DSPeer*)peer {
    if (![self.needsRequestsHashEntities count]) {
        //we are done syncing
        return;
    }
    self.requestHashEntities = [[self.needsRequestsHashEntities subarrayWithRange:NSMakeRange(0, MIN(self.needsRequestsHashes.count,REQUEST_MASTERNODE_BROADCAST_COUNT))] mutableCopy];
    NSMutableArray * requestHashes = [NSMutableArray array];
    for (DSMasternodeBroadcastHashEntity * masternodeBroadcastHashEntity in self.requestHashEntities) {
        [requestHashes addObject:masternodeBroadcastHashEntity.masternodeBroadcastHash];
    }
    [peer sendGetdataMessageWithMasternodeBroadcastHashes:requestHashes];
}

- (void)peer:(DSPeer *)peer hasMasternodeBroadcastHashes:(NSSet*)masternodeBroadcastHashes {
    NSLog(@"peer relayed masternode broadcasts");
    NSMutableOrderedSet * hashesToInsert = [[NSOrderedSet orderedSetWithSet:masternodeBroadcastHashes] mutableCopy];
    NSMutableOrderedSet * hashesToUpdate = [[NSOrderedSet orderedSetWithSet:masternodeBroadcastHashes] mutableCopy];
    NSMutableOrderedSet * hashesToQuery = [[NSOrderedSet orderedSetWithSet:masternodeBroadcastHashes] mutableCopy];
    NSMutableOrderedSet <NSData*> * rHashes = [_knownHashes mutableCopy];
    [hashesToInsert minusOrderedSet:self.knownHashes];
    [hashesToUpdate minusOrderedSet:hashesToInsert];
    [hashesToQuery minusOrderedSet:self.fulfilledRequestsHashes];
    NSMutableOrderedSet * hashesToQueryFromInsert = [hashesToQuery mutableCopy];
    [hashesToQueryFromInsert intersectOrderedSet:hashesToInsert];
    NSMutableArray * hashEntitiesToQuery = [NSMutableArray array];
    if ([masternodeBroadcastHashes count]) {
        [self.managedObjectContext performBlockAndWait:^{
            [DSMasternodeBroadcastHashEntity setContext:self.managedObjectContext];
            if ([hashesToInsert count]) {
                NSArray * novelMasternodeBroadcastHashEntities = [DSMasternodeBroadcastHashEntity masternodeBroadcastHashEntitiesWithHashes:hashesToInsert onChain:self.chain.chainEntity];
                for (DSMasternodeBroadcastHashEntity * masternodeBroadcastHashEntity in novelMasternodeBroadcastHashEntities) {
                    if ([hashesToQueryFromInsert containsObject:masternodeBroadcastHashEntity.masternodeBroadcastHash]) {
                        [hashEntitiesToQuery addObject:masternodeBroadcastHashEntity];
                    }
                }
            }
            if ([hashesToUpdate count]) {
                [DSMasternodeBroadcastHashEntity updateTimestampForMasternodeBroadcastHashEntitiesWithMasternodeBroadcastHashes:hashesToUpdate onChain:self.chain.chainEntity];
            }
            [DSMasternodeBroadcastHashEntity saveContext];
        }];
        if ([hashesToInsert count]) {
            [rHashes addObjectsFromArray:[hashesToInsert array]];
            [rHashes sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
                UInt256 a = *(UInt256 *)((NSData*)obj1).bytes;
                UInt256 b = *(UInt256 *)((NSData*)obj2).bytes;
                return uint256_sup(a,b)?NSOrderedAscending:NSOrderedDescending;
            }];
        }
    }
    
    
    
    NSMutableArray <NSData*> * rNeedsRequestsHashEntities = [self.needsRequestsHashEntities mutableCopy];
    [rNeedsRequestsHashEntities addObjectsFromArray:hashEntitiesToQuery];
    [rNeedsRequestsHashEntities sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        UInt256 a = *(UInt256 *)((NSData*)((DSMasternodeBroadcastHashEntity*)obj1).masternodeBroadcastHash).bytes;
        UInt256 b = *(UInt256 *)((NSData*)((DSMasternodeBroadcastHashEntity*)obj2).masternodeBroadcastHash).bytes;
        return uint256_sup(a,b)?NSOrderedAscending:NSOrderedDescending;
    }];
    self.knownHashes = rHashes;
    self.needsRequestsHashEntities = rNeedsRequestsHashEntities;
    NSLog(@"-> %lu - %d",(unsigned long)[self.knownHashes count],[self countForMasternodeSyncCountInfo:DSMasternodeSyncCountInfo_List]);
    NSUInteger countAroundNow = [self recentMasternodeBroadcastHashesCount];
    if ([self.knownHashes count] > [self countForMasternodeSyncCountInfo:DSMasternodeSyncCountInfo_List]) {
        [self.managedObjectContext performBlockAndWait:^{
            [DSMasternodeBroadcastHashEntity setContext:self.managedObjectContext];
            NSLog(@"countAroundNow -> %lu - %d",(unsigned long)countAroundNow,[self countForMasternodeSyncCountInfo:DSMasternodeSyncCountInfo_List]);
            if (countAroundNow == [self countForMasternodeSyncCountInfo:DSMasternodeSyncCountInfo_List]) {
                [DSMasternodeBroadcastHashEntity removeOldest:[self countForMasternodeSyncCountInfo:DSMasternodeSyncCountInfo_List] - [self.knownHashes count] onChain:self.chain.chainEntity];
                [self requestMasternodeBroadcastsFromPeer:peer];
            }
        }];
    } else if (countAroundNow == [self countForMasternodeSyncCountInfo:DSMasternodeSyncCountInfo_List]) {
        NSLog(@"%@",@"All masternode broadcast hashes received");
        //we have all hashes, let's request objects.
        [self requestMasternodeBroadcastsFromPeer:peer];
    }
}

- (void)peer:(DSPeer * )peer relayedMasternodeBroadcast:(DSMasternodeBroadcast * )masternodeBroadcast {
    NSData *masternodeBroadcastHash = [NSData dataWithUInt256:masternodeBroadcast.masternodeBroadcastHash];
    DSMasternodeBroadcastHashEntity * relatedHashEntity = nil;
    for (DSMasternodeBroadcastHashEntity * masternodeBroadcastHashEntity in [self.requestHashEntities copy]) {
        if ([masternodeBroadcastHashEntity.masternodeBroadcastHash isEqual:masternodeBroadcastHash]) {
            relatedHashEntity = masternodeBroadcastHashEntity;
            [self.requestHashEntities removeObject:masternodeBroadcastHashEntity];
            break;
        }
    }
    NSAssert(relatedHashEntity, @"There needs to be a relatedHashEntity");
    if (!relatedHashEntity) return;
    [[DSMasternodeBroadcastEntity managedObject] setAttributesFromMasternodeBroadcast:masternodeBroadcast forHashEntity:relatedHashEntity];
    [self.needsRequestsHashEntities removeObject:relatedHashEntity];
    [self.masternodeBroadcasts addObject:masternodeBroadcast];
    if (![self.requestHashEntities count]) {
        [self requestMasternodeBroadcastsFromPeer:peer];
        [DSMasternodeBroadcastEntity saveContext];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListChangedNotification object:self userInfo:nil];
        });
    }
}

- (void)peer:(DSPeer * _Nullable)peer relayedMasternodePing:(DSMasternodePing*  _Nonnull)masternodePing {
    
}

//-(void)saveBroadcast:(DSMasternodeBroadcast*)masternodeBroadcast forHashEntity:(DSMasternodeBroadcastHashEntity*)masternodeBroadcastHashEntity {
//    NSLog(@"[DSMasternodeManager] save broadcasts");
//    if ([self.masternodeBroadcasts count]) {
//
//        NSAssert(self.managedObjectContext == masternodeBroadcastHashEntity.managedObjectContext, @"must be same contexts");
//
//
//
//
//
//    }
//}


// MARK: - Masternodes

- (uint32_t)countForMasternodeSyncCountInfo:(DSMasternodeSyncCountInfo)masternodeSyncCountInfo {
    if (![self.masternodeSyncCountInfo objectForKey:@(masternodeSyncCountInfo)]) return 0;
    return (uint32_t)[[self.masternodeSyncCountInfo objectForKey:@(masternodeSyncCountInfo)] unsignedLongValue];
}

-(void)setCount:(uint32_t)count forMasternodeSyncCountInfo:(DSMasternodeSyncCountInfo)masternodeSyncCountInfo {
    [self.masternodeSyncCountInfo setObject:@(count) forKey:@(masternodeSyncCountInfo)];
}

@end
