//
//  DSDerivationPathEntity+CoreDataClass.m
//  
//
//  Created by Sam Westrich on 5/20/18.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "DSDerivationPathEntity+CoreDataClass.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChain+Protected.h"
#import "DSWallet.h"
#import "DSAccount.h"
#import "DSDerivationPath.h"
#import "NSManagedObject+Sugar.h"
#import "DSBIP39Mnemonic.h"
#import "DSAccountEntity+CoreDataClass.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"

@implementation DSDerivationPathEntity

+ (DSDerivationPathEntity* _Nonnull)derivationPathEntityMatchingDerivationPath:(DSDerivationPath*)derivationPath inContext:(NSManagedObjectContext*)context {
    NSAssert(derivationPath.standaloneExtendedPublicKeyUniqueID, @"standaloneExtendedPublicKeyUniqueID must be set");
    //DSChain * chain = derivationPath.chain;
    NSArray * derivationPathEntities;
    NSData * archivedDerivationPath = [NSKeyedArchiver archivedDataWithRootObject:derivationPath];
    DSChainEntity * chainEntity = [derivationPath.chain chainEntityInContext:context];
    //NSUInteger count = [chainEntity.derivationPaths count];
    derivationPathEntities = [[chainEntity.derivationPaths objectsPassingTest:^BOOL(DSDerivationPathEntity * _Nonnull obj, BOOL * _Nonnull stop) {
        return ([obj.publicKeyIdentifier isEqualToString:derivationPath.standaloneExtendedPublicKeyUniqueID]);
    }] allObjects];
    
    //&& [obj.derivationPath isEqualToData:archivedDerivationPath]
    if ([derivationPathEntities count]) {
        return [derivationPathEntities firstObject];
    } else {
        DSDerivationPathEntity * derivationPathEntity = [DSDerivationPathEntity managedObject];
        derivationPathEntity.derivationPath = archivedDerivationPath;
        derivationPathEntity.chain = chainEntity;
        derivationPathEntity.publicKeyIdentifier = derivationPath.standaloneExtendedPublicKeyUniqueID;
        derivationPathEntity.syncBlockHeight = BIP39_CREATION_TIME;
        if (derivationPath.account) {
            derivationPathEntity.account = [DSAccountEntity accountEntityForWalletUniqueID:derivationPath.account.wallet.uniqueIDString index:derivationPath.account.accountNumber onChain:derivationPath.chain inContext:context];
        }
        if ([derivationPath isKindOfClass:[DSIncomingFundsDerivationPath class]]) {
            DSIncomingFundsDerivationPath * incomingFundsDerivationPath = (DSIncomingFundsDerivationPath *)derivationPath;
            NSPredicate * predicatee = [NSPredicate predicateWithFormat:@"sourceContact.associatedBlockchainIdentity.uniqueID == %@ && destinationContact.associatedBlockchainIdentity.uniqueID == %@",uint256_data(incomingFundsDerivationPath.contactSourceBlockchainIdentityUniqueId),uint256_data(incomingFundsDerivationPath.contactDestinationBlockchainIdentityUniqueId)];
            DSFriendRequestEntity * friendRequest = [DSFriendRequestEntity anyObjectForPredicate:predicatee inContext:context];
            if (friendRequest) {
                derivationPathEntity.friendRequest = friendRequest;
            }
        }
        return derivationPathEntity;
    }
}

+(DSDerivationPathEntity* _Nonnull)derivationPathEntityMatchingDerivationPath:(DSIncomingFundsDerivationPath*)derivationPath associateWithFriendRequest:(DSFriendRequestEntity*)friendRequest {
    NSAssert(derivationPath.standaloneExtendedPublicKeyUniqueID, @"standaloneExtendedPublicKeyUniqueID must be set");
    NSParameterAssert(friendRequest);
    //DSChain * chain = derivationPath.chain;
    NSData * archivedDerivationPath = [NSKeyedArchiver archivedDataWithRootObject:derivationPath];
    DSChainEntity * chainEntity = [derivationPath.chain chainEntityInContext:friendRequest.managedObjectContext];

    NSSet * derivationPathEntities = [chainEntity.derivationPaths filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"publicKeyIdentifier == %@ && chain == %@",derivationPath.standaloneExtendedPublicKeyUniqueID,derivationPath.chain.chainEntity]];
    if ([derivationPathEntities count]) {
        DSDerivationPathEntity * derivationPathEntity = [derivationPathEntities anyObject];
        return derivationPathEntity;
    } else {
        DSDerivationPathEntity * derivationPathEntity = [DSDerivationPathEntity managedObject];
        derivationPathEntity.derivationPath = archivedDerivationPath;
        derivationPathEntity.chain = chainEntity;
        derivationPathEntity.publicKeyIdentifier = derivationPath.standaloneExtendedPublicKeyUniqueID;
        derivationPathEntity.syncBlockHeight = BIP39_CREATION_TIME;
        if (derivationPath.account) {
            derivationPathEntity.account = [DSAccountEntity accountEntityForWalletUniqueID:derivationPath.account.wallet.uniqueIDString index:derivationPath.account.accountNumber onChain:derivationPath.chain inContext:friendRequest.managedObjectContext];
        }
        derivationPathEntity.friendRequest = friendRequest;
        
        return derivationPathEntity;
    }
}

+(void)deleteDerivationPathsOnChain:(DSChainEntity*)chainEntity {
    [chainEntity.managedObjectContext performBlockAndWait:^{
        NSArray * derivationPathsToDelete = [self objectsMatching:@"(chain == %@)",chainEntity];
        for (DSDerivationPathEntity * derivationPath in derivationPathsToDelete) {
            [chainEntity.managedObjectContext deleteObject:derivationPath];
        }
    }];
}

@end
