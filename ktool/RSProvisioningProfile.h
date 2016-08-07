//
//  ProvisioningProfile.h
//  resign
//
//  Created by lemon4ex on 16/7/27.
//  Copyright © 2016年 lemon4ex. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RSProvisioningProfile : NSObject

@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *created;
@property (nonatomic, copy) NSString *expires;
@property (nonatomic, copy) NSString *appID;
@property (nonatomic, copy) NSString *teamID;
@property (nonatomic, copy) NSString *rawXML;
@property (nonatomic, strong) NSDictionary *entitlements;

+ (NSArray<RSProvisioningProfile *> *)allProvisioningFiles;
- (BOOL)parseWithFilePath:(NSString *)filePath;
@end
