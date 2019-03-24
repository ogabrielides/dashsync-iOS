//
//  DSBlockchainUser.m
//  DashSync
//
//  Created by Sam Westrich on 7/26/18.
//

#import "DSBlockchainUser.h"
#import "DSChain.h"
#import "DSECDSAKey.h"
#import "DSAccount.h"
#import "DSWallet.h"
#import "DSDerivationPath.h"
#import "NSCoder+Dash.h"
#import "NSMutableData+Dash.h"
#import "DSBlockchainUserRegistrationTransaction.h"
#import "DSBlockchainUserTopupTransaction.h"
#import "DSBlockchainUserResetTransaction.h"
#import "DSBlockchainUserCloseTransaction.h"
#import "DSAuthenticationManager.h"
#import "DSPriceManager.h"
#import "DSPeerManager.h"
#import "DSDerivationPathFactory.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSDerivationPathFactory.h"
#import "DSSpecialTransactionsWalletHolder.h"
#import "DSTransition.h"
#import <ios-dpp/DSDAPObjectsFactory.h>
#import <ios-dpp/DSSchemaObject.h>
#import <ios-dpp/DSSchemaHashUtils.h>
#import <DSJSONSchemaValidation/NSDictionary+DSJSONDeepMutableCopy.h>
#import <TinyCborObjc/NSObject+DSCborEncoding.h>
#import "DSChainManager.h"
#import "DSDAPIClient.h"
#import "DSContact.h"
#import "DSContactEntity+CoreDataClass.h"
#import "DSContactRequestEntity+CoreDataClass.h"
#import "DSAccountEntity+CoreDataClass.h"

static NSString * const ContactsDAPId = @"9ae7bb6e437218d8be36b04843f63a135491c898ff22d1ead73c43e105cc2444";
static NSString * const DashpayDAPId = @"7723be402fbd457bc8e8435addd4efcbe41c1d548db9fc3075a03bb68929fc61";

static NSString * const DashpayNativeDAPId = @"bea82ff8176ed01eb323b0cfab098ab0fd55531c5bd8a16caa232e5edb4cdb40";

#define BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY @"BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY"

@interface DSBlockchainUser()

@property (nonatomic,strong) DSWallet * wallet;
@property (nonatomic,strong) NSString * username;
@property (nonatomic,strong) NSString * uniqueIdentifier;
@property (nonatomic,assign) uint32_t index;
@property (nonatomic,assign) UInt256 registrationTransactionHash;
@property (nonatomic,assign) UInt256 lastTransitionHash;
@property (nonatomic,assign) uint64_t creditBalance;

@property(nonatomic,strong) DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction;
@property(nonatomic,strong) NSMutableArray <DSBlockchainUserTopupTransaction*>* blockchainUserTopupTransactions;
@property(nonatomic,strong) NSMutableArray <DSBlockchainUserCloseTransaction*>* blockchainUserCloseTransactions; //this is also a transition
@property(nonatomic,strong) NSMutableArray <DSBlockchainUserResetTransaction*>* blockchainUserResetTransactions; //this is also a transition
@property(nonatomic,strong) NSMutableArray <DSTransition*>* baseTransitions;
@property(nonatomic,strong) NSMutableArray <DSTransaction*>* allTransitions;

@property (copy, nonatomic) NSArray <NSString *> *contacts;
@property (copy, nonatomic) NSArray <NSString *> *outgoingContactRequests;
@property (copy, nonatomic) NSArray <NSString *> *incomingContactRequests;

@property (nonatomic,readonly) DSDAPIClient * dapiClient;

@property (nonatomic, strong) NSManagedObjectContext * managedObjectContext;

@end

@implementation DSBlockchainUser

-(instancetype)initWithUsername:(NSString*)username atIndex:(uint32_t)index inWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext*)managedObjectContext {
    if (!(self = [super init])) return nil;
    self.username = username;
    self.uniqueIdentifier = [NSString stringWithFormat:@"%@_%@_%@",BLOCKCHAIN_USER_UNIQUE_IDENTIFIER_KEY,wallet.chain.uniqueID,username];
    self.wallet = wallet;
    self.registrationTransactionHash = UINT256_ZERO;
    self.index = index;
    self.blockchainUserTopupTransactions = [NSMutableArray array];
    self.blockchainUserCloseTransactions = [NSMutableArray array];
    self.blockchainUserResetTransactions = [NSMutableArray array];
    self.baseTransitions = [NSMutableArray array];
    self.allTransitions = [NSMutableArray array];
    self.contacts = @[];
    self.outgoingContactRequests = @[];
    self.incomingContactRequests = @[];
    if (managedObjectContext) {
        self.managedObjectContext = managedObjectContext;
    } else {
        self.managedObjectContext = [NSManagedObject context];
    }
    
    __weak typeof(self) weakSelf = self;
    [self.dapiClient getUserByName:self.username success:^(NSDictionary * _Nullable profileDictionary) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        uint64_t creditBalance = (uint64_t)[profileDictionary[@"credits"] longLongValue];
        strongSelf.creditBalance = creditBalance;
    } failure:^(NSError * _Nonnull error) {
        
    }];
    return self;
}

-(void)loadContacts {
    [self.managedObjectContext performBlockAndWait:^{
        [DSContactEntity setContext:self.managedObjectContext];
        [DSAccountEntity setContext:self.managedObjectContext];
        [DSContactRequestEntity setContext:self.managedObjectContext];
        [DSDerivationPathEntity setContext:self.managedObjectContext];
        NSArray<DSContactEntity *>* contacts = [DSContactEntity objectsMatching:@"ownerBlockchainUserRegistrationTransaction.transactionHash.txHash == %@",uint256_data(self.registrationTransactionHash)];
        NSMutableArray * contactArray = [NSMutableArray array];
        for (DSContactEntity *e in contacts) {
            DSAccount * account = [self.wallet accountWithNumber:e.account.index];
            [contactArray addObject:[[DSContact alloc] initWithUsername:e.username contactsBlockchainUserRegistrationTransactionHash:e.blockchainUserRegistrationHash.UInt256 blockchainUserOwner:self account:account]];
        }
        self.contacts = [contactArray copy];
    }];

}

-(instancetype)initWithUsername:(NSString*)username atIndex:(uint32_t)index inWallet:(DSWallet*)wallet createdWithTransactionHash:(UInt256)registrationTransactionHash lastTransitionHash:(UInt256)lastTransitionHash inContext:(NSManagedObjectContext*)managedObjectContext {
    if (!(self = [self initWithUsername:username atIndex:index inWallet:wallet inContext:managedObjectContext])) return nil;
    self.registrationTransactionHash = registrationTransactionHash;
    self.lastTransitionHash = lastTransitionHash; //except topup and close, including state transitions
    
    [self loadContacts];
    
    return self;
}

-(instancetype)initWithBlockchainUserRegistrationTransaction:(DSBlockchainUserRegistrationTransaction*)blockchainUserRegistrationTransaction inContext:(NSManagedObjectContext*)managedObjectContext {
    uint32_t index = 0;
    DSWallet * wallet = [blockchainUserRegistrationTransaction.chain walletHavingBlockchainUserAuthenticationHash:blockchainUserRegistrationTransaction.pubkeyHash foundAtIndex:&index];
    if (!(self = [self initWithUsername:blockchainUserRegistrationTransaction.username atIndex:index inWallet:wallet inContext:(NSManagedObjectContext*)managedObjectContext])) return nil;
    self.registrationTransactionHash = blockchainUserRegistrationTransaction.txHash;
    self.blockchainUserRegistrationTransaction = blockchainUserRegistrationTransaction;
    return self;
}

-(void)generateBlockchainUserExtendedPublicKey:(void (^ _Nullable)(BOOL registered))completion {
    __block DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] blockchainUsersKeysDerivationPathForWallet:self.wallet];
    if ([derivationPath hasExtendedPublicKey]) {
        completion(YES);
        return;
    }
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:@"Generate Blockchain User" forWallet:self.wallet forAmount:0 forceAuthentication:NO completion:^(NSData * _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(NO);
            return;
        }
        [derivationPath generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:self.wallet.uniqueID];
        completion(YES);
    }];
}

-(void)registerInWallet {
    [self.wallet registerBlockchainUser:self];
}

-(void)registrationTransactionForTopupAmount:(uint64_t)topupAmount fundedByAccount:(DSAccount*)fundingAccount completion:(void (^ _Nullable)(DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction))completion {
    NSString * question = [NSString stringWithFormat:DSLocalizedString(@"Are you sure you would like to register the username %@ and spend %@ on credits?", nil),self.username,[[DSPriceManager sharedInstance] stringForDashAmount:topupAmount]];
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:question forWallet:self.wallet forAmount:topupAmount forceAuthentication:YES completion:^(NSData * _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(nil);
            return;
        }
        DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] blockchainUsersKeysDerivationPathForWallet:self.wallet];
        DSECDSAKey * privateKey = (DSECDSAKey *)[derivationPath privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:self.index] fromSeed:seed];

        DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction = [[DSBlockchainUserRegistrationTransaction alloc] initWithBlockchainUserRegistrationTransactionVersion:1 username:self.username pubkeyHash:[privateKey.publicKeyData hash160] onChain:self.wallet.chain];
        [blockchainUserRegistrationTransaction signPayloadWithKey:privateKey];
        NSMutableData * opReturnScript = [NSMutableData data];
        [opReturnScript appendUInt8:OP_RETURN];
        [fundingAccount updateTransaction:blockchainUserRegistrationTransaction forAmounts:@[@(topupAmount)] toOutputScripts:@[opReturnScript] withFee:YES isInstant:NO];
        
        completion(blockchainUserRegistrationTransaction);
    }];
}

-(void)topupTransactionForTopupAmount:(uint64_t)topupAmount fundedByAccount:(DSAccount*)fundingAccount completion:(void (^ _Nullable)(DSBlockchainUserTopupTransaction * blockchainUserTopupTransaction))completion {
    NSString * question = [NSString stringWithFormat:DSLocalizedString(@"Are you sure you would like to topup %@ and spend %@ on credits?", nil),self.username,[[DSPriceManager sharedInstance] stringForDashAmount:topupAmount]];
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:question forWallet:self.wallet forAmount:topupAmount forceAuthentication:YES completion:^(NSData * _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(nil);
            return;
        }
        DSBlockchainUserTopupTransaction * blockchainUserTopupTransaction = [[DSBlockchainUserTopupTransaction alloc] initWithBlockchainUserTopupTransactionVersion:1 registrationTransactionHash:self.registrationTransactionHash onChain:self.wallet.chain];
        
        NSMutableData * opReturnScript = [NSMutableData data];
        [opReturnScript appendUInt8:OP_RETURN];
        [fundingAccount updateTransaction:blockchainUserTopupTransaction forAmounts:@[@(topupAmount)] toOutputScripts:@[opReturnScript] withFee:YES isInstant:NO];

        completion(blockchainUserTopupTransaction);
    }];
    
}

-(void)resetTransactionUsingNewIndex:(uint32_t)index completion:(void (^ _Nullable)(DSBlockchainUserResetTransaction * blockchainUserResetTransaction))completion {
    NSString * question = DSLocalizedString(@"Are you sure you would like to reset this user?", nil);
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:question forWallet:self.wallet forAmount:0 forceAuthentication:YES completion:^(NSData * _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(nil);
            return;
        }
        DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] blockchainUsersKeysDerivationPathForWallet:self.wallet];
        DSECDSAKey * oldPrivateKey = (DSECDSAKey *)[derivationPath privateKeyAtIndex:self.index fromSeed:seed];
        DSECDSAKey * privateKey = (DSECDSAKey *)[derivationPath privateKeyAtIndex:index fromSeed:seed];
        
        DSBlockchainUserResetTransaction * blockchainUserResetTransaction = [[DSBlockchainUserResetTransaction alloc] initWithBlockchainUserResetTransactionVersion:1 registrationTransactionHash:self.registrationTransactionHash previousBlockchainUserTransactionHash:self.lastTransitionHash replacementPublicKeyHash:[privateKey.publicKeyData hash160] creditFee:1000 onChain:self.wallet.chain];
        [blockchainUserResetTransaction signPayloadWithKey:oldPrivateKey];
        DSDLog(@"%@",blockchainUserResetTransaction.toData);
        completion(blockchainUserResetTransaction);
    }];
}

-(void)updateWithTopupTransaction:(DSBlockchainUserTopupTransaction*)blockchainUserTopupTransaction save:(BOOL)save {
    if (![_blockchainUserTopupTransactions containsObject:blockchainUserTopupTransaction]) {
        [_blockchainUserTopupTransactions addObject:blockchainUserTopupTransaction];
        if (save) {
            [self save];
        }
    }
}

-(void)updateWithResetTransaction:(DSBlockchainUserResetTransaction*)blockchainUserResetTransaction save:(BOOL)save {
    if (![_blockchainUserResetTransactions containsObject:blockchainUserResetTransaction]) {
        [_blockchainUserResetTransactions addObject:blockchainUserResetTransaction];
        [_allTransitions addObject:blockchainUserResetTransaction];
        if (save) {
            [self save];
        }
    }
}

-(void)updateWithCloseTransaction:(DSBlockchainUserCloseTransaction*)blockchainUserCloseTransaction save:(BOOL)save {
    if (![_blockchainUserCloseTransactions containsObject:blockchainUserCloseTransaction]) {
        [_blockchainUserCloseTransactions addObject:blockchainUserCloseTransaction];
        [_allTransitions addObject:blockchainUserCloseTransaction];
        if (save) {
            [self save];
        }
    }
}

-(void)updateWithTransition:(DSTransition*)transition save:(BOOL)save {
    if (![_baseTransitions containsObject:transition]) {
        [_baseTransitions addObject:transition];
        [_allTransitions addObject:transition];
        if (save) {
            [self save];
        }
    }
}


-(DSBlockchainUserRegistrationTransaction*)blockchainUserRegistrationTransaction {
    if (!_blockchainUserRegistrationTransaction) {
        _blockchainUserRegistrationTransaction = (DSBlockchainUserRegistrationTransaction*)[self.wallet.specialTransactionsHolder transactionForHash:self.registrationTransactionHash];
    }
    return _blockchainUserRegistrationTransaction;
}

-(UInt256)lastTransitionHash {
    //this is not effective, do this locally in the future
    return [self.wallet.specialTransactionsHolder lastSubscriptionTransactionHashForRegistrationTransactionHash:self.registrationTransactionHash];
}

-(DSTransition*)transitionForStateTransitionPacketHash:(UInt256)stateTransitionHash {
    DSTransition * transition = [[DSTransition alloc] initWithTransitionVersion:1 registrationTransactionHash:self.registrationTransactionHash previousTransitionHash:self.lastTransitionHash creditFee:1000 packetHash:stateTransitionHash onChain:self.wallet.chain];
    return transition;
}

-(void)signStateTransition:(DSTransition*)transition withPrompt:(NSString*)prompt completion:(void (^ _Nullable)(BOOL success))completion {
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:prompt forWallet:self.wallet forAmount:0 forceAuthentication:YES completion:^(NSData* _Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(NO);
            return;
        }
        DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] blockchainUsersKeysDerivationPathForWallet:self.wallet];
        DSECDSAKey * privateKey = (DSECDSAKey *)[derivationPath privateKeyAtIndex:self.index fromSeed:seed];
        NSLog(@"%@",uint160_hex(privateKey.publicKeyData.hash160));
        
        NSLog(@"%@",uint160_hex(self.blockchainUserRegistrationTransaction.pubkeyHash));
        NSAssert(uint160_eq(privateKey.publicKeyData.hash160,self.blockchainUserRegistrationTransaction.pubkeyHash),@"Keys aren't ok");
        [transition signPayloadWithKey:privateKey];
        completion(YES);
    }];
}

// MARK: - Layer 2

- (void)sendDapObject:(NSMutableDictionary<NSString *, id> *)dapObject completion:(void (^)(BOOL success))completion {
    NSMutableArray *dapObjects = [NSMutableArray array];
    [dapObjects addObject:dapObject];
    
    NSMutableDictionary<NSString *, id> *stPacket = [[DSDAPObjectsFactory createSTPacketInstance] ds_deepMutableCopy];
    NSMutableDictionary<NSString *, id> *stPacketObject = stPacket[DS_STPACKET];
    stPacketObject[DS_DAPOBJECTS] = dapObjects;
    stPacketObject[@"dapid"] = DashpayNativeDAPId;
    
    NSData *serializedSTPacketObject = [stPacketObject ds_cborEncodedObject];
    
    __block NSData *serializedSTPacketObjectHash = [DSSchemaHashUtils hashOfObject:stPacketObject];
    
    __block DSTransition *transition = [self transitionForStateTransitionPacketHash:serializedSTPacketObjectHash.UInt256];
    
    [self signStateTransition:transition
                                  withPrompt:@"" completion:^(BOOL success) {
                                      if (success) {
                                          NSData *transitionData = [transition toData];
                                          
                                          NSString *transitionDataHex = [transitionData hexString];
                                          NSString *serializedSTPacketObjectHex = [serializedSTPacketObject hexString];
                                          
                                          [self.wallet.chain.chainManager.DAPIClient sendRawTransitionWithRawTransitionHeader:transitionDataHex rawTransitionPacket:serializedSTPacketObjectHex success:^(NSString * _Nonnull headerId) {
                                              NSLog(@"Header ID %@", headerId);
                                              
                                              [self.wallet.chain registerSpecialTransaction:transition];
                                              [transition save];
                                              
                                              if (completion) {
                                                  completion(YES);
                                              }
                                          } failure:^(NSError * _Nonnull error) {
                                              NSLog(@"Error: %@", error);
                                              if (completion) {
                                                  completion(NO);
                                              }
                                          }];
                                      }
                                      else {
                                          if (completion) {
                                              completion(NO);
                                          }
                                      }
                                  }];
}

- (void)sendNewContactRequestToUserWithUsername:(NSString *)username completion:(void (^)(BOOL))completion {
    __weak typeof(self) weakSelf = self;
    [self.dapiClient getUserByName:username success:^(NSDictionary * _Nullable blockchainUser) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        if (!blockchainUser) {
            if (completion) {
                completion(NO);
            }
            
            return;
        }
        
        NSMutableDictionary<NSString *, id> *contactObject = [DSDAPObjectsFactory createDAPObjectForTypeName:@"contact"];
        contactObject[@"user"] = blockchainUser[@"regtxid"];
        contactObject[@"username"] = username;
        
        NSMutableDictionary<NSString *, id> *me = [NSMutableDictionary dictionary];
        me[@"id"] = uint256_hex(strongSelf.registrationTransactionHash);
        me[@"username"] = strongSelf.username;
        
        contactObject[@"sender"] = me;
        
        [strongSelf sendDapObject:contactObject completion:^(BOOL success) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            
            if (success) {
                strongSelf.outgoingContactRequests = [strongSelf.outgoingContactRequests arrayByAddingObject:username];
                
                //remove the incoming contact request as well
                NSMutableArray <NSString *> *incomingContactRequests = [strongSelf.incomingContactRequests mutableCopy];
                [incomingContactRequests removeObject:username];
                strongSelf.incomingContactRequests = [incomingContactRequests copy];
            }
        
            
            if (completion) {
                completion(success);
            }
        }];
    } failure:^(NSError * _Nonnull error) {
        
    }];
}

- (void)createProfileWithBioString:(NSString*)bio completion:(void (^)(BOOL success))completion {
    NSMutableDictionary<NSString *, id> *userObject = [DSDAPObjectsFactory createDAPObjectForTypeName:@"user"];
    userObject[@"aboutme"] = bio;
    userObject[@"username"] = self.username;
    
    __weak typeof(self) weakSelf = self;
    [self sendDapObject:userObject completion:^(BOOL success) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        if (success) {
            if (completion) {
                completion(YES);
            }
        }
        else {
            if (completion) {
                completion(NO);
            }
        }
    }];
}

-(DSDAPIClient*)dapiClient {
    return self.wallet.chain.chainManager.DAPIClient;
}

- (void)fetchProfile:(void (^)(BOOL success))completion {
    NSDictionary *query = @{@"": uint256_hex(self.registrationTransactionHash)};
    DSDAPIClientFetchDapObjectsOptions *options = [[DSDAPIClientFetchDapObjectsOptions alloc] initWithWhereQuery:query orderBy:nil limit:nil startAt:nil startAfter:nil];
    
    __weak typeof(self) weakSelf = self;
    [self.wallet.chain.chainManager.DAPIClient fetchDapObjectsForId:DashpayNativeDAPId objectsType:@"user" options:options success:^(NSArray<NSDictionary *> * _Nonnull dapObjects) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        [strongSelf handleContacts:dapObjects];
        
        if (completion) {
            completion(YES);
        }
    } failure:^(NSError * _Nonnull error) {
        if (completion) {
            completion(NO);
        }
    }];
}

- (void)fetchContacts:(void (^)(BOOL success))completion {
    NSDictionary *query = @{@"data.user": uint256_hex(self.registrationTransactionHash)};
    DSDAPIClientFetchDapObjectsOptions *options = [[DSDAPIClientFetchDapObjectsOptions alloc] initWithWhereQuery:query orderBy:nil limit:nil startAt:nil startAfter:nil];
    
    __weak typeof(self) weakSelf = self;
    [self.wallet.chain.chainManager.DAPIClient fetchDapObjectsForId:DashpayNativeDAPId objectsType:@"contact" options:options success:^(NSArray<NSDictionary *> * _Nonnull dapObjects) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        [strongSelf handleContacts:dapObjects];
        
        if (completion) {
            completion(YES);
        }
    } failure:^(NSError * _Nonnull error) {
        if (completion) {
            completion(NO);
        }
    }];
}


- (void)handleContacts:(NSArray<NSDictionary *> *)rawContacts {
    NSMutableArray <NSString *> *contactsAndIncomingRequests = [NSMutableArray array];
    for (NSDictionary *rawContact in rawContacts) {
        NSDictionary *sender = rawContact[@"sender"];
        NSString *username = sender[@"username"];
        [contactsAndIncomingRequests addObject:username];
    }
    
    NSMutableArray <NSString *> *contacts = [NSMutableArray array];
    NSMutableArray <NSString *> *outgoingContactRequests = [self.outgoingContactRequests mutableCopy];
    NSMutableArray <NSString *> *incomingContactRequests = [NSMutableArray array];
    
    for (NSString *username in contactsAndIncomingRequests) {
        if ([outgoingContactRequests containsObject:username]) { // it's a match!
            [outgoingContactRequests removeObject:username];
            [contacts addObject:username];
        }
        else { // incoming request
            [incomingContactRequests addObject:username];
        }
    }
    
    self.contacts = contacts;
    self.outgoingContactRequests = outgoingContactRequests;
    self.incomingContactRequests = incomingContactRequests;
}


// MARK: - Persistence

-(void)save {
//    NSManagedObjectContext * context = [DSTransactionEntity context];
//    [context performBlockAndWait:^{ // add the transaction to core data
//        [DSChainEntity setContext:context];
//        [DSLocalMasternodeEntity setContext:context];
//        [DSTransactionHashEntity setContext:context];
//        [DSProviderRegistrationTransactionEntity setContext:context];
//        [DSProviderUpdateServiceTransactionEntity setContext:context];
//        [DSProviderUpdateRegistrarTransactionEntity setContext:context];
//        [DSProviderUpdateRevocationTransactionEntity setContext:context];
//        if ([DSLocalMasternodeEntity
//             countObjectsMatching:@"providerRegistrationTransaction.transactionHash.txHash == %@", uint256_data(self.providerRegistrationTransaction.txHash)] == 0) {
//            DSProviderRegistrationTransactionEntity * providerRegistrationTransactionEntity = [DSProviderRegistrationTransactionEntity anyObjectMatching:@"transactionHash.txHash == %@", uint256_data(self.providerRegistrationTransaction.txHash)];
//            if (!providerRegistrationTransactionEntity) {
//                providerRegistrationTransactionEntity = (DSProviderRegistrationTransactionEntity *)[self.providerRegistrationTransaction save];
//            }
//            DSLocalMasternodeEntity * localMasternode = [DSLocalMasternodeEntity managedObject];
//            [localMasternode setAttributesFromLocalMasternode:self];
//            [DSLocalMasternodeEntity saveContext];
//        } else {
//            DSLocalMasternodeEntity * localMasternode = [DSLocalMasternodeEntity anyObjectMatching:@"providerRegistrationTransaction.transactionHash.txHash == %@", uint256_data(self.providerRegistrationTransaction.txHash)];
//            [localMasternode setAttributesFromLocalMasternode:self];
//            [DSLocalMasternodeEntity saveContext];
//        }
//    }];
}


@end
