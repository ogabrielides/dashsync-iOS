//
//  DSGovernanceObject.h
//  DashSync
//
//  Created by Sam Westrich on 6/11/18.
//

#import <Foundation/Foundation.h>

@class DSChain;

typedef NS_ENUM(uint32_t, DSGovernanceObjectType) {
    DSGovernanceObjectType_Uknown = 0,
    DSGovernanceObjectType_Proposal = 1,
    DSGovernanceObjectType_Trigger = 2,
    DSGovernanceObjectType_Watchdog = 3, //deprecated
};

@interface DSGovernanceObject : NSObject

@property (nonatomic, readonly) UInt256 collateralHash;
@property (nonatomic, readonly) UInt256 parentHash;
@property (nonatomic, readonly) uint32_t revision;
@property (nonatomic, readonly) NSData *signature;
@property (nonatomic, readonly) NSTimeInterval timestamp;
@property (nonatomic, readonly) DSGovernanceObjectType type;
@property (nonatomic, readonly) UInt256 governanceObjectHash;
@property (nonatomic, readonly) NSString * governanceMessage;
@property (nonatomic, readonly) DSChain * chain;

+(DSGovernanceObject* _Nullable)governanceObjectFromMessage:(NSData * _Nonnull)message onChain:(DSChain* _Nonnull)chain;
-(instancetype)initWithType:(DSGovernanceObjectType)governanceObjectType governanceMessage:(NSString* _Nonnull)governanceMessage parentHash:(UInt256)parentHash revision:(uint32_t)revision timestamp:(NSTimeInterval)timestamp signature:(NSData* _Nullable)signature collateralHash:(UInt256)collateralHash governanceObjectHash:(UInt256)governanceObjectHash onChain:(DSChain* _Nonnull)chain;

@end
