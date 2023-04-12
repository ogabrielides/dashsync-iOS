//
//  DSQuorumEntry.m
//  DashSync
//
//  Created by Sam Westrich on 4/25/19.
//

#import "DSQuorumEntry.h"
#import "DSBlock.h"
#import "DSChainManager.h"
#import "DSMasternodeList.h"
#import "DSMasternodeList+Mndiff.h"
#import "DSMasternodeManager.h"
#import "DSMerkleBlock.h"
#import "DSQuorumEntry+Mndiff.h"
#import "DSQuorumEntryEntity+CoreDataClass.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"

@interface DSQuorumEntry ()

@property (nonatomic, assign) uint16_t version;
@property (nonatomic, assign) uint32_t quorumIndex;
@property (nonatomic, assign) UInt256 quorumHash;
@property (nonatomic, assign) UInt384 quorumPublicKey;
@property (nonatomic, assign) UInt768 quorumThresholdSignature;
@property (nonatomic, assign) UInt256 quorumVerificationVectorHash;
@property (nonatomic, assign) UInt768 allCommitmentAggregatedSignature;
@property (nonatomic, assign) int32_t signersCount;
@property (nonatomic, assign) LLMQType llmqType;
@property (nonatomic, assign) int32_t validMembersCount;
@property (nonatomic, strong) NSData *signersBitset;
@property (nonatomic, strong) NSData *validMembersBitset;
@property (nonatomic, assign) UInt256 quorumEntryHash;
@property (nonatomic, assign) UInt256 commitmentHash;
@property (nonatomic, assign) uint32_t length;
@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, assign) BOOL verified;

@end

@implementation DSQuorumEntry

- (id)copyWithZone:(NSZone *)zone {
    DSQuorumEntry *copy = [[[self class] alloc] init];
    if (!copy) return nil;
    // Copy NSObject subclasses
    [copy setSignersBitset:self.signersBitset];
    [copy setValidMembersBitset:self.validMembersBitset];

    // Set primitives
    [copy setVersion:self.version];
    [copy setQuorumHash:self.quorumHash];
    [copy setQuorumPublicKey:self.quorumPublicKey];
    [copy setQuorumThresholdSignature:self.quorumThresholdSignature];
    [copy setQuorumVerificationVectorHash:self.quorumVerificationVectorHash];
    [copy setAllCommitmentAggregatedSignature:self.allCommitmentAggregatedSignature];
    [copy setSignersCount:self.signersCount];
    [copy setLlmqType:self.llmqType];
    [copy setValidMembersCount:self.validMembersCount];
    [copy setQuorumEntryHash:self.quorumEntryHash];
    [copy setCommitmentHash:self.commitmentHash];
//    [copy setLength:self.length];
    [copy setQuorumIndex:self.quorumIndex];
    [copy setChain:self.chain];

    return copy;
}

- (instancetype)initWithVersion:(uint16_t)version
                           type:(LLMQType)type
                     quorumHash:(UInt256)quorumHash
                    quorumIndex:(uint32_t)quorumIndex
                   signersCount:(int32_t)signersCount
                  signersBitset:(NSData *)signersBitset
              validMembersCount:(int32_t)validMembersCount
             validMembersBitset:(NSData *)validMembersBitset
                quorumPublicKey:(UInt384)quorumPublicKey
   quorumVerificationVectorHash:(UInt256)quorumVerificationVectorHash
       quorumThresholdSignature:(UInt768)quorumThresholdSignature
allCommitmentAggregatedSignature:(UInt768)allCommitmentAggregatedSignature
                quorumEntryHash:(UInt256)quorumEntryHash
                        onChain:(DSChain *)chain {
    if (!(self = [super init])) return nil;

    self.llmqType = type;
    self.version = version;
    self.quorumHash = quorumHash;
    self.quorumIndex = quorumIndex;
    self.signersCount = signersCount;
    self.signersBitset = signersBitset;
    self.validMembersCount = validMembersCount;
    self.validMembersBitset = validMembersBitset;
    self.quorumPublicKey = quorumPublicKey;
    self.quorumVerificationVectorHash = quorumVerificationVectorHash;
    self.quorumVerificationVectorHash = quorumVerificationVectorHash;
    self.quorumThresholdSignature = quorumThresholdSignature;
    self.allCommitmentAggregatedSignature = allCommitmentAggregatedSignature;
    self.quorumEntryHash = quorumEntryHash;
    self.chain = chain;

    return self;
}

- (instancetype)initWithVersion:(uint16_t)version type:(LLMQType)type quorumHash:(UInt256)quorumHash quorumIndex:(uint32_t)quorumIndex quorumPublicKey:(UInt384)quorumPublicKey quorumEntryHash:(UInt256)quorumEntryHash verified:(BOOL)verified onChain:(DSChain *)chain {
    if (!(self = [super init])) return nil;

    self.llmqType = type;
    self.version = version;
    self.quorumHash = quorumHash;
    self.quorumPublicKey = quorumPublicKey;
    self.quorumEntryHash = quorumEntryHash;
    self.quorumIndex = quorumIndex;
    self.verified = verified;
    self.chain = chain;
    self.saved = TRUE;

    return self;
}

- (instancetype)initWithEntry:(LLMQEntry *)entry onChain:(DSChain *)chain {
    if (!(self = [super init])) return nil;
    self.allCommitmentAggregatedSignature = *((UInt768 *)entry->all_commitment_aggregated_signature);
    if (entry->commitment_hash) {
        self.commitmentHash = *((UInt256 *)entry->commitment_hash);
    }
    self.llmqType = entry->llmq_type;
    self.quorumEntryHash = *((UInt256 *)entry->entry_hash);
    self.quorumHash = *((UInt256 *)entry->llmq_hash);
    self.quorumPublicKey = *((UInt384 *)entry->public_key);
    self.quorumThresholdSignature = *((UInt768 *)entry->threshold_signature);
    self.quorumVerificationVectorHash = *((UInt256 *)entry->verification_vector_hash);
    self.quorumIndex = entry->index;
    self.saved = entry->saved;
    self.signersBitset = [NSData dataWithBytes:entry->signers_bitset length:entry->signers_bitset_length];
    self.signersCount = (uint32_t)entry->signers_count;
    self.validMembersBitset = [NSData dataWithBytes:entry->valid_members_bitset length:entry->valid_members_bitset_length];
    self.validMembersCount = (uint32_t)entry->valid_members_count;
    self.verified = entry->verified;
    self.version = entry->version;
    self.chain = chain;
    return self;
}

- (NSData *)toData {
    NSMutableData *data = [NSMutableData data];
    [data appendUInt16:self.version];
    [data appendUInt8:self.llmqType];
    [data appendUInt256:self.quorumHash];
    // LLMQVersion::Indexed || LLMQVersion::BLSBasicIndexed
    if (self.version == 2 || self.version == 4)
        [data appendUInt32:self.quorumIndex];
    [data appendVarInt:self.signersCount];
    [data appendData:self.signersBitset];
    [data appendVarInt:self.validMembersCount];
    [data appendData:self.validMembersBitset];
    [data appendUInt384:self.quorumPublicKey];
    [data appendUInt256:self.quorumVerificationVectorHash];
    [data appendUInt768:self.quorumThresholdSignature];
    [data appendUInt768:self.allCommitmentAggregatedSignature];
    return data;
}

- (UInt256)commitmentHash {
    if (uint256_is_zero(_commitmentHash)) {
        NSData *data = [self commitmentData];
        _commitmentHash = [data SHA256_2];
    }
    return _commitmentHash;
}

- (NSData *)commitmentData {
    NSMutableData *data = [NSMutableData data];
    [data appendVarInt:self.llmqType];
    [data appendUInt256:self.quorumHash];
    // LLMQVersion::Indexed || LLMQVersion::BLSBasicIndexed
    if (self.version == 2 || self.version == 4)
        [data appendUInt32:self.quorumIndex];
    [data appendVarInt:self.validMembersCount];
    [data appendData:self.validMembersBitset];
    [data appendUInt384:self.quorumPublicKey];
    [data appendUInt256:self.quorumVerificationVectorHash];
    return data;
}

- (uint32_t)quorumThreshold {
    switch (self.llmqType) { //!OCLINT
        case LLMQType_LlmqtypeUnknown: return 2;
        case LLMQType_Llmqtype50_60: return 30;
        case LLMQType_Llmqtype400_60: return 240;
        case LLMQType_Llmqtype400_85: return 340;
        case LLMQType_Llmqtype100_67: return 67;
        case LLMQType_Llmqtype60_75: return 48;
        case LLMQType_Llmqtype25_67: return 17;
        case LLMQType_LlmqtypeTest: return 3;
        case LLMQType_LlmqtypeDevnet: return 6;
        case LLMQType_LlmqtypeTestV17: return 2;
        case LLMQType_LlmqtypeDevnetDIP0024: return 4;
        case LLMQType_LlmqtypeTestnetPlatform: return 8;
        case LLMQType_LlmqtypeDevnetPlatform: return 8;
        default:
            NSAssert(FALSE, @"Unknown llmq type");
            return UINT32_MAX;
    }
}

- (UInt256)llmqQuorumHash {
    NSMutableData *data = [NSMutableData data];
    [data appendVarInt:self.llmqType];
    [data appendUInt256:self.quorumHash];
    return [data SHA256_2];
}

- (BOOL)validateWithMasternodeList:(DSMasternodeList *)masternodeList {
    return [self validateWithMasternodeList:masternodeList
                          blockHeightLookup:^uint32_t(UInt256 blockHash) {
                              DSMerkleBlock *block = [self.chain blockForBlockHash:blockHash];
                              if (!block) {
                                  DSLog(@"Unknown block %@", uint256_reverse_hex(blockHash));
                                  NSAssert(block, @"block should be known");
                              }
                              return block.height;
                          }];
}

//- (BOOL)validateBitsets {
//    //The byte size of the signers and validMembers bitvectors must match “(quorumSize + 7) / 8”
//    if (self.signersBitset.length != (self.signersCount + 7) / 8) {
//        DSLog(@"Error: The byte size of the signers bitvectors (%lu) must match “(quorumSize + 7) / 8 (%d)", (unsigned long)self.signersBitset.length, (self.signersCount + 7) / 8);
//        return NO;
//    }
//    if (self.validMembersBitset.length != (self.validMembersCount + 7) / 8) {
//        DSLog(@"Error: The byte size of the validMembers bitvectors (%lu) must match “(quorumSize + 7) / 8 (%d)", (unsigned long)self.validMembersBitset.length, (self.validMembersCount + 7) / 8);
//        return NO;
//    }
//
//    //No out-of-range bits should be set in byte representation of the signers and validMembers bitvectors
//    uint32_t signersOffset = self.signersCount / 8;
//    uint8_t signersLastByte = [self.signersBitset UInt8AtOffset:signersOffset];
//    uint8_t signersMask = UINT8_MAX >> (8 - signersOffset) << (8 - signersOffset);
//    if (signersLastByte & signersMask) {
//        DSLog(@"Error: No out-of-range bits should be set in byte representation of the signers bitvector");
//        return NO;
//    }
//
//    uint32_t validMembersOffset = self.validMembersCount / 8;
//    uint8_t validMembersLastByte = [self.validMembersBitset UInt8AtOffset:validMembersOffset];
//    uint8_t validMembersMask = UINT8_MAX >> (8 - validMembersOffset) << (8 - validMembersOffset);
//    if (validMembersLastByte & validMembersMask) {
//        DSLog(@"Error: No out-of-range bits should be set in byte representation of the validMembers bitvector");
//        return NO;
//    }
//    return YES;
//}

- (BOOL)validateWithMasternodeList:(DSMasternodeList *)masternodeList blockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    if (!masternodeList) {
        DSLog(@"Trying to validate a quorum without a masternode list");
        return NO;
    }
    MasternodeList *list = [masternodeList ffi_malloc];
    LLMQEntry *quorum = [self ffi_malloc];
    BOOL is_valid = validate_masternode_list(list, quorum, blockHeightLookup(masternodeList.blockHash));
    [DSMasternodeList ffi_free:list];
    [DSQuorumEntry ffi_free:quorum];
    self.verified = is_valid;
    return is_valid;
//
//    //The quorumHash must match the current DKG session
//    //todo
//    BOOL hasValidBitsets = [self validateBitsets];
//    if (!hasValidBitsets) {
//        return NO;
//    }
//
//    //The number of set bits in the signers and validMembers bitvectors must be at least >= quorumThreshold
//    if ([self.signersBitset trueBitsCount] < [self quorumThreshold]) {
//        DSLog(@"Error: The number of set bits in the signers bitvector %llu must be at least >= quorumThreshold %d", [self.signersBitset trueBitsCount], [self quorumThreshold]);
//        return NO;
//    }
//    if ([self.validMembersBitset trueBitsCount] < [self quorumThreshold]) {
//        DSLog(@"Error: The number of set bits in the validMembers bitvector %llu must be at least >= quorumThreshold %d", [self.validMembersBitset trueBitsCount], [self quorumThreshold]);
//        return NO;
//    }
//
//    //The quorumSig must validate against the quorumPublicKey and the commitmentHash. As this is a recovered threshold signature, normal signature verification can be performed, without the need of the full quorum verification vector. The commitmentHash is calculated in the same way as in the commitment phase.
//
//    NSArray<DSSimplifiedMasternodeEntry *> *masternodes = [masternodeList validMasternodesForQuorumModifier:self.llmqQuorumHash quorumCount:[DSQuorumEntry quorumSizeForType:self.llmqType] blockHeightLookup:blockHeightLookup];
//    uint32_t blockHeight = blockHeightLookup(masternodeList.blockHash);
//    // TODO: rust migration LLMQEntry.validate_payload()
//    // LLMQEntry.validate(&mut self, valid_masternodes: Vec<models::MasternodeEntry>, block_height: u32) -> bool;
//
//    NSMutableArray<NSValue *> *publicKeyArray = [NSMutableArray array];
////    NSMutableArray<DSBLSKey *> *publicKeyArray = [NSMutableArray array];
//    uint32_t i = 0;
//    for (DSSimplifiedMasternodeEntry *masternodeEntry in masternodes) {
//        if ([self.signersBitset bitIsTrueAtLEIndex:i]) {
//            UInt384 pkData = [masternodeEntry operatorPublicKeyAtBlockHeight:blockHeight];
//            OpaqueKey *key = key_create_with_public_key_data(pkData.u8, 48, self.useLegacyBLSScheme ? DSKeyType_BLS : DSKeyType_BLS_BASIC);
//            NSValue *masternodePublicKey = [NSValue valueWithPointer:key];
////            DSBLSKey *masternodePublicKey = [DSBLSKey keyWithPublicKey:pkData useLegacy:self.useLegacyBLSScheme];
//            [publicKeyArray addObject:masternodePublicKey];
//        }
//        i++;
//    }
//
//    BOOL allCommitmentAggregatedSignatureValidated = [DSBLSKey verifySecureAggregated:self.commitmentHash signature:self.allCommitmentAggregatedSignature withPublicKeys:publicKeyArray useLegacy:self.useLegacyBLSScheme];
//    if (!allCommitmentAggregatedSignatureValidated) {
//        DSLog(@"Issue with allCommitmentAggregatedSignatureValidated for quorum of type %d quorumHash %@ llmqHash %@ commitmentHash %@ signersBitset %@ (%d signers) at height %u", self.llmqType, uint256_hex(self.commitmentHash), uint256_hex(self.quorumHash), uint256_hex(self.commitmentHash), self.signersBitset.hexString, self.signersCount, masternodeList.height);
//        return NO;
//    }
//
//    //The sig must validate against the commitmentHash and all public keys determined by the signers bitvector. This is an aggregated BLS signature verification.
//
//    BOOL quorumSignatureValidated = [DSBLSKey verify:self.commitmentHash signature:self.quorumThresholdSignature withPublicKey:self.quorumPublicKey useLegacy:self.useLegacyBLSScheme];
//    //    NSLog(@"validateQuorumCallback verify = %i, with: commitmentHash: %@, quorumThresholdSignature: %@, quorumPublicKey: %@", quorumSignatureValidated, uint256_hex(self.commitmentHash), uint768_hex(self.quorumThresholdSignature), uint384_hex(self.quorumPublicKey));
//
//    if (!quorumSignatureValidated) {
//        DSLog(@"Issue with quorumSignatureValidated");
//        return NO;
//    }
//    //    NSLog(@"validateQuorumCallback true");
//
//    self.verified = YES;
//
//    return YES;
}

- (DSQuorumEntryEntity *)matchingQuorumEntryEntityInContext:(NSManagedObjectContext *)context {
    return [DSQuorumEntryEntity anyObjectInContext:context matching:@"quorumPublicKeyData == %@", uint384_data(self.quorumPublicKey)];
}

- (UInt256)orderingHashForRequestID:(UInt256)requestID forQuorumType:(LLMQType)quorumType {
    NSMutableData *data = [NSMutableData data];
    [data appendVarInt:quorumType];
    [data appendUInt256:self.quorumHash];
    [data appendUInt256:requestID];
    return [data SHA256_2];
}

+ (uint32_t)quorumSizeForType:(LLMQType)type {
    switch (type) { //!OCLINT
        case LLMQType_LlmqtypeUnknown: return 50;
        case LLMQType_Llmqtype50_60: return 50;
        case LLMQType_Llmqtype400_60: return 400;
        case LLMQType_Llmqtype400_85: return 400;
        case LLMQType_Llmqtype100_67: return 100;
        case LLMQType_Llmqtype60_75: return 60;
        case LLMQType_Llmqtype25_67: return 25;
        case LLMQType_LlmqtypeTest: return 4;
        case LLMQType_LlmqtypeDevnet: return 12;
        case LLMQType_LlmqtypeTestV17: return 3;
        case LLMQType_LlmqtypeTestDIP0024: return 4;
        case LLMQType_LlmqtypeDevnetDIP0024: return 8;
        case LLMQType_LlmqtypeTestnetPlatform: return 8;
        case LLMQType_LlmqtypeDevnetPlatform: return 8;
        default:
            NSAssert(FALSE, @"Unknown quorum type");
            return 50;
    }
}


- (NSString *)description {
    uint32_t height = [self.chain heightForBlockHash:self.quorumHash];
    return [[super description] stringByAppendingString:[NSString stringWithFormat:@" - %u", height]];
}

- (NSString *)debugDescription {
    uint32_t height = [self.chain heightForBlockHash:self.quorumHash];
    return [[super debugDescription] stringByAppendingString:[NSString stringWithFormat:@" - %u -%u", height, self.version]];
}

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isKindOfClass:[DSQuorumEntry class]]) return NO;
    return uint256_eq(self.quorumEntryHash, ((DSQuorumEntry *)object).quorumEntryHash);
}

- (NSUInteger)hash {
    return [uint256_data(self.quorumEntryHash) hash];
}

- (void)mergedWithQuorumEntry:(DSQuorumEntry *)quorumEntry {
    self.allCommitmentAggregatedSignature = quorumEntry.allCommitmentAggregatedSignature;
    self.commitmentHash = quorumEntry.commitmentHash;
    self.llmqType = quorumEntry.llmqType;
    self.quorumEntryHash = quorumEntry.quorumEntryHash;
    self.quorumHash = quorumEntry.quorumHash;
    self.quorumPublicKey = quorumEntry.quorumPublicKey;
    self.quorumThresholdSignature = quorumEntry.quorumThresholdSignature;
    self.quorumVerificationVectorHash = quorumEntry.quorumVerificationVectorHash;
    self.quorumIndex = quorumEntry.quorumIndex;
    self.saved = quorumEntry.saved;
    self.signersBitset = quorumEntry.signersBitset;
    self.signersCount = quorumEntry.signersCount;
    self.validMembersBitset = quorumEntry.validMembersBitset;
    self.validMembersCount = quorumEntry.validMembersCount;
    self.verified = quorumEntry.verified;
    self.version = quorumEntry.version;
    self.chain = quorumEntry.chain;
}

- (BOOL)useLegacyBLSScheme {
    return self.version <= 2;
}

@end
