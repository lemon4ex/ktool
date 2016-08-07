//
//  RSInjector.h
//  resign
//
//  Created by lemon4ex on 16/7/31.
//  Copyright © 2016年 lemon4ex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RSConfig.h"

@interface RSInjectorConfig : RSConfig
@property (nonatomic, strong) NSArray<NSString *> *dylibsWillInject; ///< -p files ... 将要注入到二进制文件的动态库
@end

@interface RSInjector : NSObject
- (BOOL)injectWithConfig:(RSInjectorConfig *)config;
@end
