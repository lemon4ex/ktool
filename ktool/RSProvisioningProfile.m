//
//  ProvisioningProfile.m
//  resign
//
//  Created by lemon4ex on 16/7/27.
//  Copyright © 2016年 lemon4ex. All rights reserved.
//

#import "RSProvisioningProfile.h"
#import "RSUtils.h"

@implementation RSProvisioningProfile

+ (NSArray<RSProvisioningProfile *> *)allProvisioningFiles
{
    NSMutableArray *provisioningFiles = [NSMutableArray array];
    NSString *libraryDirectory = [[NSFileManager defaultManager]URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask][0].path;
    NSString *provisioningProfilesPath = [libraryDirectory stringByAppendingPathComponent:@"MobileDevice/Provisioning Profiles"];
    NSArray<NSString *> *allFiles = [[NSFileManager defaultManager]contentsOfDirectoryAtPath:provisioningProfilesPath error:nil];
    [allFiles enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([[obj.pathExtension lowercaseString] isEqualToString:@"mobileprovision"]) {
            RSProvisioningProfile *profile = [[RSProvisioningProfile alloc]init];
            if ([profile parseWithFilePath:[provisioningProfilesPath stringByAppendingPathComponent:obj]]) {
                [provisioningFiles addObject:profile];
            }
        }
    }];
    
    return provisioningFiles;
}

- (BOOL)parseWithFilePath:(NSString *)filePath {
    RSTaskResult *result = [NSTask executeWithPath:@"/usr/bin/security" workingDirectory:nil arguments:@[@"cms",@"-D",@"-i", filePath]];
    if (result.status == 0) {
        self.rawXML = result.output;
        NSError *error;
        if ([result.output hasPrefix:@"security: SecPolicySetValue: One or more parameters passed to a function were not valid."]) {
            result.output = [result.output stringByReplacingOccurrencesOfString:@"security: SecPolicySetValue: One or more parameters passed to a function were not valid." withString:@""];
        }
        NSDictionary *info = [NSPropertyListSerialization propertyListWithData:[result.output dataUsingEncoding:NSUTF8StringEncoding] options:NSPropertyListImmutable format:0 error:&error];
        if (!error) {
            self.filePath = filePath;
            self.expires = info[@"ExpirationDate"];
            self.created = info[@"CreationDate"];
            self.name = info[@"Name"];
            self.entitlements = info[@"Entitlements"];
            NSString *applicationIdentifier = self.entitlements[@"application-identifier"];
            NSRange range = [applicationIdentifier rangeOfString:@"."];
            self.appID = [applicationIdentifier substringFromIndex:range.location + range.length];
            self.teamID = [applicationIdentifier substringToIndex:range.length + range.location - 1];
            return YES;
        }
        else {
            NSLog(@"Error Parse file %@ ,error %@",filePath,error);
            return NO;
        }
    }
    else{
        NSLog(@"Error reading %@",filePath);
        return NO;
    }
}

@end
