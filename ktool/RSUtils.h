//
//  Utils.h
//  resign
//
//  Created by lemon4ex on 16/7/27.
//  Copyright © 2016年 lemon4ex. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const kBundleID;
extern NSString *const kArPath;
extern NSString *const kMktempPath;
extern NSString *const kTarPath;
extern NSString *const kUnzipPath;
extern NSString *const kZipPath;
extern NSString *const kDefaultsPath;
extern NSString *const kCodesignPath;
extern NSString *const kSecurityPath;
extern NSString *const kChmodPath;
extern NSString *const kCpPath;

#define RSLog(FORMAT, ...) \
do {\
if (_config.debugFlag) {\
fprintf(stderr,"%s\n",[[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);\
}\
} while (0)


@interface RSTaskResult : NSObject
@property (nonatomic, assign) NSInteger status;
@property (nonatomic, copy) NSString *output;
@end

@interface NSTask (RSUtils)
- (RSTaskResult *)sycLaunch;
+ (RSTaskResult *)executeWithPath:(NSString *)launchPath workingDirectory:(NSString *)workingDirectory arguments:(NSArray *)arguments;
@end

