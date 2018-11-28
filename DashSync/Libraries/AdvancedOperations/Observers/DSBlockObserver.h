//
//  Created by Andrew Podkovyrin
//  Copyright © 2018 Dash Core Group. All rights reserved.
//  Copyright © 2015 Michal Zaborowski. All rights reserved.
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

#import "DSOperationObserverProtocol.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^DSBlockObserverWillStartHandler)(DSOperation *operation, DSOperationQueue *operationQueue);
typedef void (^DSBlockObserverStartHandler)(DSOperation *operation);
typedef void (^DSBlockObserverProduceHandler)(DSOperation *operation, NSOperation *producedOperation);
typedef void (^DSBlockObserverFinishHandler)(DSOperation *operation, NSArray<NSError *> *_Nullable errors);

/**
 The `DSBlockObserver` is a way to attach arbitrary blocks to significant events
 in an `DSOperation`'s lifecycle.
 */
@interface DSBlockObserver : NSObject <DSOperationObserverProtocol>

- (instancetype)initWithWillStartHandler:(nullable DSBlockObserverWillStartHandler)willStartHandler
                         didStartHandler:(nullable DSBlockObserverStartHandler)startHandler
                          produceHandler:(nullable DSBlockObserverProduceHandler)produceHandler
                           finishHandler:(nullable DSBlockObserverFinishHandler)finishHandler;

@end

NS_ASSUME_NONNULL_END
