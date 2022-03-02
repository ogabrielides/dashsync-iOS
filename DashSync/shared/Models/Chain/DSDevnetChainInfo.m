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

#import "DSDevnetChainInfo.h"

#define kIdentifier @"Identifier"
#define kVersion @"Version"


@implementation DSDevnetChainInfo

+ (instancetype)devnetChainInfoWithIdentifier:(NSString *)identifier version:(uint16_t)version {
    DSDevnetChainInfo *chainInfo = [[self alloc] init];
    chainInfo.chainType = DSChainType_DevNet;
    chainInfo.identifier = identifier;
    chainInfo.version = version;
    return chainInfo;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (id)copyWithZone:(NSZone *)zone {
    DSDevnetChainInfo *copy = [[[self class] alloc] init];
    copy.chainType = self.chainType;
    copy.identifier = self.identifier;
    copy.version = self.version;
    return copy;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (!(self = [super initWithCoder:decoder])) return nil;
    self.identifier = [decoder decodeObjectForKey:kIdentifier];
    self.version = [decoder decodeIntForKey:kVersion];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:self.identifier forKey:kIdentifier];
    [aCoder encodeInt:self.version forKey:kVersion];
}

- (BOOL)isEqual:(id)object {
    DSDevnetChainInfo *obj = (DSDevnetChainInfo *)object;
    return self.chainType == obj.chainType && self.identifier == obj.identifier && self.version == obj.version;
}

- (NSUInteger)hash {
    return self.chainType ^ self.identifier.hash ^ self.version;
}

@end
