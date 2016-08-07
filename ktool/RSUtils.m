//
//  Utils.m
//  resign
//
//  Created by lemon4ex on 16/7/27.
//  Copyright © 2016年 lemon4ex. All rights reserved.
//

#import "RSUtils.h"

NSString *const kBundleID = @"net.aigudao.ktool";
NSString *const kArPath = @"/usr/bin/ar";
NSString *const kMktempPath = @"/usr/bin/mktemp";
NSString *const kTarPath = @"/usr/bin/tar";
NSString *const kUnzipPath = @"/usr/bin/unzip";
NSString *const kZipPath = @"/usr/bin/zip";
NSString *const kDefaultsPath = @"/usr/bin/defaults";
NSString *const kCodesignPath = @"/usr/bin/codesign";
NSString *const kSecurityPath = @"/usr/bin/security";
NSString *const kChmodPath = @"/bin/chmod";
NSString *const kCpPath = @"/bin/cp";

@implementation RSTaskResult
@end

@implementation NSTask (RSUtils)

- (RSTaskResult *)sycLaunch {
    self.standardInput = [NSFileHandle fileHandleWithNullDevice];
    NSPipe *pipe = [NSPipe pipe];
    self.standardOutput = pipe;
    self.standardError = pipe;
    [self launch];
    NSMutableData *outData = [NSMutableData data];
    NSFileHandle *file = [pipe fileHandleForReading];
    while (self.running) {
        [outData appendData:file.availableData];
    }
    
    RSTaskResult *result = [[RSTaskResult alloc]init];
    result.status = self.terminationStatus;
    result.output = [[NSString alloc]initWithData:outData encoding:NSUTF8StringEncoding];
    return result;
}

+ (RSTaskResult *)executeWithPath:(NSString *)launchPath workingDirectory:(NSString *)workingDirectory arguments:(NSArray *)arguments
{
    NSTask *task = [[NSTask alloc]init];
    task.launchPath = launchPath;
    if (arguments) {
        task.arguments = arguments;
    }
    
    if (workingDirectory) {
        task.currentDirectoryPath = workingDirectory;
    }
    
    return [task sycLaunch];
}
@end
