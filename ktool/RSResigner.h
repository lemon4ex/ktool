//
//  Resign.h
//  resign
//
//  Created by lemon4ex on 16/7/27.
//  Copyright © 2016年 lemon4ex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RSConfig.h"

@interface RSResignerConfig : RSConfig
@property (nonatomic, copy) NSString *certName; ///< -c .cert证书路径
@property (nonatomic, copy) NSString *mobileProvisionPath; ///< -m .mobileProvision文件路径
@property (nonatomic, copy) NSString *bundleIdentifier; ///< -i info.plist里的bundleIdentifier
@property (nonatomic, copy) NSString *bundleName; ///< -n info.plist里的bundleName
@property (nonatomic, copy) NSString *bundleDisplayName; ///< -N info.plist里的bundleDisplayName
@property (nonatomic, copy) NSString *bundleShortVersion; ///< -v info.plist里的bundleShortVersion
@property (nonatomic, copy) NSString *bundleVersion; ///< -V info.plist里的bundleVersion
@property (nonatomic, strong) NSArray<NSString *> *filesWillAdd; ///< -a files ... 将要添加并且打包的文件
@property (nonatomic, strong) NSArray<NSString *> *dylibsWillInject; ///< -p files ... 将要注入到二进制文件的动态库
@property (nonatomic, copy) NSString *entitlementsPlistPath; ///< -e file entitlementsPlist 文件路径
@end

@interface RSResigner : NSObject

- (BOOL)resignWithConfig:(RSResignerConfig *)config;

@end

