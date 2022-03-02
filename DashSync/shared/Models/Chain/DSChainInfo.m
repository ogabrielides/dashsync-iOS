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

#import "DSChainInfo.h"

#define kChainType @"ChainType"

@implementation DSChainInfo

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (id)copyWithZone:(NSZone *)zone {
    DSChainInfo *copy = [[[self class] alloc] init];
    //    copy.protocolVersion = self.protocolVersion;
    //    copy.minProtocolVersion = self.minProtocolVersion;
    copy.chainType = self.chainType;
    return copy;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (!(self = [super init])) return nil;
    self.chainType = [decoder decodeIntForKey:kChainType];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInt:self.chainType forKey:kChainType];
}

- (BOOL)isEqual:(id)object {
    DSChainInfo *obj = (DSChainInfo *)object;
    return self.chainType == obj.chainType;
}

- (NSUInteger)hash {
    return self.chainType;
}

@end
