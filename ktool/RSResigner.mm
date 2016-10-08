//
//  Resign.m
//  resign
//
//  Created by lemon4ex on 16/7/27.
//  Copyright © 2016年 lemon4ex. All rights reserved.
//

#import "RSResigner.h"
#import "RSUtils.h"
#import "RSProvisioningProfile.h"
#import "RSInjector.h"

@implementation RSResignerConfig

@end

@implementation RSResigner
{
    RSResignerConfig *_config;
    NSString *_workingDirectory;
    NSString *_tempDirectory;
    NSString *_payloadDirectory;
    NSString *_entitlementsPlist;
//    NSString *_eggDirectory;
    NSMutableArray *_frameworks;
    NSMutableArray *_plugIns;
    NSMutableArray *_embeddedApps;
    NSFileManager *_fileManager;
}

- (instancetype)init
{
    if (self = [super init]) {
        _fileManager = [NSFileManager defaultManager];

    }
    
    return self;
}

- (BOOL)resignWithConfig:(RSResignerConfig *)config {
    _config = config;
    
    RSTaskResult *taskResult = [NSTask executeWithPath:kMktempPath workingDirectory:nil arguments:@[@"-d",@"-t",kBundleID]];
    
    if (taskResult.status != 0) {
        RSLog(@"Create temp directory failed");
        return NO;
    }
    
    _tempDirectory = [taskResult.output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    _workingDirectory = [_tempDirectory stringByAppendingPathComponent:@"unzip"];
    _payloadDirectory = [_workingDirectory stringByAppendingPathComponent:@"Payload"];
//    _eggDirectory = [_tempDirectory stringByAppendingPathComponent:@"eggs"];
    _entitlementsPlist = [_tempDirectory stringByAppendingPathComponent:@"entitlements.plist"];
    
    RSLog(@"Temp folder: %@",_tempDirectory);
    RSLog(@"Working directory: %@",_workingDirectory);
    RSLog(@"Payload directory: %@",_payloadDirectory);
//    RSLog(@"Egg directory: %@",_eggDirectory);
    
    
    [_fileManager createDirectoryAtPath:_workingDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    
    printf("Extracting ipa file\n");
    
    taskResult = [NSTask executeWithPath:kUnzipPath workingDirectory:nil arguments:@[@"-q",_config.inputPath?:@"",@"-d",_workingDirectory]];
    
    if (taskResult.status != 0) {
        RSLog(@"Error extracting ipa file");
        printf("\e[31mResign failed\e[0m\n");
        [self cleanUpTempDirectory];
        return NO;
    }
    
    NSError *error;

    NSArray<NSString *> *contentFiles = [[NSFileManager defaultManager]contentsOfDirectoryAtPath:_payloadDirectory error:&error];
    if (!contentFiles) {
        RSLog(@"Error getting files in payload directory %@",_payloadDirectory);
        printf("\e[31mResign failed\e[0m\n");
        [self cleanUpTempDirectory];
        return NO;
    }

    BOOL isDir = NO;
    
    for (NSString *file in contentFiles) {
        NSString *appBundlePath = [_payloadDirectory stringByAppendingPathComponent:file]; //.app
        
        if (![_fileManager fileExistsAtPath:appBundlePath isDirectory:&isDir] || !isDir) {
            continue;
        }
        
        NSString *appBundleInfoPlist = [appBundlePath stringByAppendingPathComponent:@"Info.plist"];
        if (![_fileManager fileExistsAtPath:appBundleInfoPlist]) {
            RSLog(@"Error getting Info.plist file");
            continue;
        }
        
        do {
            
            taskResult = [NSTask executeWithPath:kDefaultsPath workingDirectory:nil arguments:@[@"delete",appBundleInfoPlist,@"CFBundleResourceSpecification"]];
            
            NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:appBundleInfoPlist];
            
            NSString *appBundleProvisioningFilePath = [appBundlePath stringByAppendingPathComponent:@"embedded.mobileprovision"];
            if(![self copyProvisioningProfile:appBundleProvisioningFilePath]) break;
            
            NSString *originBundleIdentifier = infoPlist[@"CFBundleIdentifier"];
            if (!_config.entitlementsPlistPath && [_fileManager fileExistsAtPath:appBundleProvisioningFilePath])
            {
                if (![self generatEntitlementsPlistWithBundleIdentifier:originBundleIdentifier appBundleProvisioningFilePath:appBundleProvisioningFilePath]) break;
            }
            
            NSString *appBundleExecutableFilePath = [appBundlePath stringByAppendingPathComponent:infoPlist[@"CFBundleExecutable"]];
            // Chmod file
            [NSTask executeWithPath:kChmodPath workingDirectory:nil arguments:@[@"755",appBundleExecutableFilePath]];
            
            if (![self copyFilesToAppBundle:appBundlePath]) break;
            
            if ([_config.dylibsWillInject count] > 0) {
                if (![self injectFilesToAppBundleExecutableFilePath:appBundleExecutableFilePath]) break;
            }
            
            _frameworks = [NSMutableArray array];
            _plugIns = [NSMutableArray array];
            _embeddedApps = [NSMutableArray array];
            
            [self searchFilesForSignInPath:appBundlePath];
            
            if (_config.bundleIdentifier) {
                if (![self modifyEmbeddedAppInfoPlistWithContainerBundleIdnetifier:originBundleIdentifier]) break;
                if (![self modifyAppexInfoPlistWithContainerBundleIdnetifier:originBundleIdentifier]) break;
            }
            
            if (![self modifyBundleInfoPlistWithPath:appBundleInfoPlist]) break;
            
            if (![self signAllNeedFiles]) break;
            
            if (![self codeSignFileWithPath:appBundlePath]) break;
            
            if (![self verifyCodesigningWithFilePath:appBundlePath]) break;
            
            if (![self packagingFilesToIPA]) break;
            
            if (![self copyIPAToOutputPath]) break;
            
            printf("\e[32mDone, output at %s\e[0m\n",[_config.outputPath UTF8String]);
            
            [self cleanUpTempDirectory];
            
            return YES;
            
        } while (0);
        
        break;
    }
    
    printf("\e[31mResign failed\e[0m\n");
    [self cleanUpTempDirectory];
    return NO;
    
}

- (BOOL)copyIPAToOutputPath
{
    NSError *error;
    if (![_fileManager copyItemAtPath:[_workingDirectory stringByAppendingPathComponent:[_config.outputPath lastPathComponent]]  toPath:_config.outputPath error:&error]) {
        RSLog(@"Error copy IPA");
        RSLog(@"%@",error.localizedDescription);
        return NO;
    }
    
    return YES;
}

- (BOOL)packagingFilesToIPA
{
    printf("Packaging IPA\n");
    
    RSTaskResult *taskResult = [NSTask executeWithPath:kZipPath workingDirectory:_workingDirectory arguments:@[@"-qry", [_config.outputPath lastPathComponent], @"."]];
    if (taskResult.status != 0) {
        RSLog(@"Error packaging IPA");
        return NO;
    }
    
    return YES;

}

- (BOOL)signAllNeedFiles
{
    for (NSString *framework in _frameworks) {
        if (![self codeSignFileWithPath:framework]) {
            return NO;
        }
    }
    
    for (NSString *plugin in _plugIns) {
        if (![self codeSignFileWithPath:plugin]) {
            return NO;
        }
    }
    
    for (NSString *embeddedApp in _embeddedApps) {
        if (![self codeSignFileWithPath:embeddedApp]) {
            return NO;
        }
    }

    return YES;
}

- (BOOL)modifyAppexInfoPlistWithContainerBundleIdnetifier:(NSString *)containerBundleIdnetifier
{
    for (NSString *plugin in _plugIns) {
        NSString *pluginInfoPlistPath = [plugin stringByAppendingPathComponent:@"Info.plist"];
        if (![_fileManager fileExistsAtPath:pluginInfoPlistPath]) {
            continue;
        }
        
        NSMutableDictionary *pluginInfoPlist = [NSMutableDictionary dictionaryWithContentsOfFile:pluginInfoPlistPath];
        
        NSString *pluginBundleIdnetifier = pluginInfoPlist[@"CFBundleIdentifier"];
        printf("Modify plugin's Info.plist value for CFBundleIdentifier\n");
        pluginInfoPlist[@"CFBundleIdentifier"] = [pluginBundleIdnetifier stringByReplacingOccurrencesOfString:containerBundleIdnetifier withString:_config.bundleIdentifier];
        
        NSString *wkAppBundleIdentifier = pluginInfoPlist[@"NSExtension"][@"NSExtensionAttributes"][@"WKAppBundleIdentifier"];
        if (wkAppBundleIdentifier) {
            pluginInfoPlist[@"NSExtension"][@"NSExtensionAttributes"][@"WKAppBundleIdentifier"] = [wkAppBundleIdentifier stringByReplacingOccurrencesOfString:containerBundleIdnetifier withString:_config.bundleIdentifier];
        }
        
        if (![pluginInfoPlist writeToFile:pluginInfoPlistPath atomically:NO]) {
            RSLog(@"Error writing pluginInfoPlist");
            return NO;
        }
        
    }
    
    return YES;
}

- (BOOL)modifyEmbeddedAppInfoPlistWithContainerBundleIdnetifier:(NSString *)containerBundleIdnetifier
{
    for (NSString *embeddedApp in _embeddedApps) {
        NSString *embeddedAppInfoPlistPath = [embeddedApp stringByAppendingPathComponent:@"Info.plist"];
        
        if (![_fileManager fileExistsAtPath:embeddedAppInfoPlistPath]) {
            continue;
        }
        
        NSMutableDictionary *embeddedAppInfoPlist = [NSMutableDictionary dictionaryWithContentsOfFile:embeddedAppInfoPlistPath];
        if (embeddedAppInfoPlist[@"WKCompanionAppBundleIdentifier"]) {
            printf("Modify embeddedApp's Info.plist value for WKCompanionAppBundleIdentifier\n");
            embeddedAppInfoPlist[@"WKCompanionAppBundleIdentifier"] = _config.bundleIdentifier;
        }
        
        NSString *embeddedAppBundleIdnetifier = embeddedAppInfoPlist[@"CFBundleIdentifier"];
        printf("Modify embeddedApp's Info.plist value for CFBundleIdentifier\n");
        embeddedAppInfoPlist[@"CFBundleIdentifier"] = [embeddedAppBundleIdnetifier stringByReplacingOccurrencesOfString:containerBundleIdnetifier withString:_config.bundleIdentifier];
        if (![embeddedAppInfoPlist writeToFile:embeddedAppInfoPlistPath atomically:NO]) {
            RSLog(@"Error writing embeddedAppInfoPlist");
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)injectFilesToAppBundleExecutableFilePath:(NSString *)appBundleExecutableFilePath
{
    printf("Inject files\n");
    
    RSInjector *injector = [[RSInjector alloc]init];
    RSInjectorConfig *injectConfig = [[RSInjectorConfig alloc]init];
    injectConfig.inputPath = appBundleExecutableFilePath;
    injectConfig.outputPath = appBundleExecutableFilePath;
    injectConfig.dylibsWillInject = _config.dylibsWillInject;
    if (![injector injectWithConfig:injectConfig]) {
        RSLog(@"Error inject files");
        return NO;
    }
    
    return YES;
}

- (BOOL)copyFilesToAppBundle:(NSString *)appBundlePath
{
    if ([_config.filesWillAdd count] > 0 || _config.dylibsWillInject.count > 0) {
        
        printf("Copy files to app bundle\n");
        
        // Copy files to app bundle
        NSError *error;
        for (NSString *filePath in _config.filesWillAdd) {
            NSString *targetPath = [appBundlePath stringByAppendingPathComponent:[filePath lastPathComponent]];
            
            if ([_fileManager fileExistsAtPath:targetPath]) {
                RSLog(@"File %@ is exists,so remove it",targetPath);
                if (![_fileManager removeItemAtPath:targetPath error:&error]) {
                    RSLog(@"Error remove %@",targetPath);
                }
            }
            
            if (![[NSFileManager defaultManager]copyItemAtPath:filePath toPath:targetPath error:&error]) {
                RSLog(@"Error copy %@ to app bundle,%@",filePath,error.localizedDescription);
                return NO;
            }
        }
        
        for (NSString *filePath in _config.dylibsWillInject) {
            NSString *targetPath = [appBundlePath stringByAppendingPathComponent:[filePath lastPathComponent]];
            
            if ([_fileManager fileExistsAtPath:targetPath]) {
                RSLog(@"File %@ is exists,so remove it",targetPath);
                if (![_fileManager removeItemAtPath:targetPath error:&error]) {
                    RSLog(@"Error remove %@",targetPath);
                }
            }
            
            if (![[NSFileManager defaultManager]copyItemAtPath:filePath toPath:targetPath error:&error]) {
                RSLog(@"Error copy %@ to app bundle,%@",filePath,error.localizedDescription);
                return NO;
            }
        }
    }
    
    return YES;
}

- (BOOL)generatEntitlementsPlistWithBundleIdentifier:(NSString *)originBundleIdentifier appBundleProvisioningFilePath:(NSString *)appBundleProvisioningFilePath
{
    printf("Parsing entitlements\n");
    
    RSProvisioningProfile *profile = [[RSProvisioningProfile alloc]init];
    if (![profile parseWithFilePath:appBundleProvisioningFilePath]) {
        RSLog(@"Unable to parse provisioning profile, it may be corrupt");
        return NO;
    }
    
    if (!profile.entitlements) {
        RSLog(@"Unable to read entitlements from provisioning profile");
        return NO;
    }
    
    _config.entitlementsPlistPath = [_tempDirectory stringByAppendingPathComponent:@"entitlements.plist"];
    
    NSMutableDictionary *entitlements = [profile.entitlements mutableCopy];
    
//    if (_config.bundleIdentifier) {
//        if (![profile.appID isEqualToString:@"*"] && ![profile.appID isEqualToString:_config.bundleIdentifier]) {
//            RSLog(@"Unable to change App ID to %@, provisioning profile won't allow it",_config.bundleIdentifier);
//            return NO;
//        }
//    }
    
    if ([profile.appID isEqualToString:@"*"]) {
        entitlements[@"application-identifier"] = [entitlements[@"application-identifier"] stringByReplacingOccurrencesOfString:@".*" withString:[NSString stringWithFormat:@".%@",_config.bundleIdentifier?:originBundleIdentifier]];
        
    }
    
    if (![entitlements writeToFile:_config.entitlementsPlistPath atomically:NO]) {
        RSLog(@"Error writing entitlements.plist");
        return NO;
    }
    
    RSLog(@"Saved entitlements to %@",_config.entitlementsPlistPath);
    
    return YES;
}

- (BOOL)copyProvisioningProfile:(NSString *)appBundleProvisioningFilePath
{
    NSError *error;
    // Copy Provisioning Profile
    if (![_fileManager fileExistsAtPath:_config.mobileProvisionPath]) {
        RSLog(@"Error no provisioning profile exists");
        return NO;
    }
    
    if ([_fileManager fileExistsAtPath:appBundleProvisioningFilePath]) {
        RSLog(@"Deleting embedded.mobileprovision");
        if (![_fileManager removeItemAtPath:appBundleProvisioningFilePath error:&error]) {
            
            RSLog(@"Error deleting embedded.mobileprovision");
            RSLog(@"%@",error.localizedDescription);
            return NO;
        }
    }
    
    printf("Copying provisioning profile to app bundle\n");
    
    if (![_fileManager copyItemAtPath:_config.mobileProvisionPath toPath:appBundleProvisioningFilePath error:&error]) {
        RSLog(@"Error copying provisioning profile");
        RSLog(@"%@",error.localizedDescription);
        return NO;
    }
    
    return YES;
}

- (BOOL)verifyCodesigningWithFilePath:(NSString *)appBundlePath
{
    // MARK: Codesigning - Verification
    NSError *error;
    RSTaskResult *taskResult = [NSTask executeWithPath:kCodesignPath workingDirectory:nil arguments:@[@"-v",appBundlePath]];
    if (taskResult.status != 0) {
        RSLog(@"Error verifying code signature");
        RSLog(@"%@",taskResult.output);
        return NO;
    }
    
    // Check if output already exists and delete if so
    if ([_fileManager fileExistsAtPath:_config.outputPath]){
        if (![_fileManager removeItemAtPath:_config.outputPath error:&error]) {
            RSLog(@"Error deleting output file");
            RSLog(@"%@",error.localizedDescription);
            return NO;
        }
    }
    
    return YES;
}

- (void)searchFilesForSignInPath:(NSString *)appBundlePath
{
    
    NSArray *contentFiles = [[NSFileManager defaultManager]contentsOfDirectoryAtPath:appBundlePath error:nil];
    
    for (NSString *file in contentFiles) {
        NSString *fullPath = [appBundlePath stringByAppendingPathComponent:file];
        BOOL isDir = NO;
        if ([[NSFileManager defaultManager]fileExistsAtPath:fullPath isDirectory:&isDir] && isDir) {
            if ([[[file pathExtension]lowercaseString] isEqualToString:@"app"]) {
                [_embeddedApps addObject:fullPath];
            }
            else if ([[[file pathExtension]lowercaseString] isEqualToString:@"appex"])
            {
                [_plugIns addObject:fullPath];
            }
            
            [self searchFilesForSignInPath:fullPath];
        }
        else
        {
            if ([[[file pathExtension]lowercaseString] isEqualToString:@"dylib"] || [[[file pathExtension]lowercaseString] isEqualToString:@"framework"]) {
                [_frameworks addObject:fullPath];
            }
        }
    }
}

- (BOOL)codeSignFileWithPath:(NSString *)filePath
{
    printf("Codesigning %s with entitlements\n",[[filePath lastPathComponent]UTF8String]);
    
    RSTaskResult *taskResult = [NSTask executeWithPath:kCodesignPath workingDirectory:nil arguments:@[@"-vvv",@"-fs",_config.certName,@"--entitlements",_config.entitlementsPlistPath,@"--no-strict",filePath]];
    
    if (taskResult.status != 0) {
        RSLog(@"Error codesign %@",filePath);
        return NO;
    }
    
    return YES;
}

- (BOOL)modifyBundleInfoPlistWithPath:(NSString *)appBundleInfoPlist
{
    NSMutableDictionary *infoPlist = [NSMutableDictionary dictionaryWithContentsOfFile:appBundleInfoPlist];
    if(_config.bundleIdentifier)
    {
        infoPlist[@"CFBundleIdentifier"] = _config.bundleIdentifier;
    }
    
    if (_config.bundleName) {
        infoPlist[@"CFBundleName"] = _config.bundleName;
    }
    
    if (_config.bundleDisplayName) {
        infoPlist[@"CFBundleDisplayName"] = _config.bundleDisplayName;
    }
    
    if (_config.bundleShortVersion) {
        infoPlist[@"CFBundleShortVersionString"] = _config.bundleShortVersion;
    }
    
    if (_config.bundleVersion) {
        infoPlist[@"CFBundleVersion"] = _config.bundleVersion;
    }
    
    if (![infoPlist writeToFile:appBundleInfoPlist atomically:NO]) {
        RSLog(@"Error modify Info.plist");
        return NO;
    }
    
    return YES;
}

- (void)cleanUpTempDirectory
{
    RSLog(@"Deleting:%@",_tempDirectory);
    NSError *error;
    if(![[NSFileManager defaultManager]removeItemAtPath:_tempDirectory error:&error])
    {
        RSLog(@"Unable to delete temp folder %@",_tempDirectory);
    }
}

@end
