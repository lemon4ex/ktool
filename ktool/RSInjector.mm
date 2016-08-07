//
//  RSInjector.m
//  resign
//
//  Created by lemon4ex on 16/7/31.
//  Copyright © 2016年 lemon4ex. All rights reserved.
//

#import "RSInjector.h"
#import "RSUtils.h"
#include <mach-o/loader.h>
#include <mach-o/fat.h>

@implementation RSInjectorConfig

@end

@implementation RSInjector
{
    RSInjectorConfig *_config;
    NSString *_tempDirectory;
    NSString *_tempFilePath;
}

- (BOOL)injectWithConfig:(RSInjectorConfig *)config {
    _config = config;
    
    do {
        if (![[NSFileManager defaultManager] fileExistsAtPath:_config.inputPath])
        {
            RSLog(@"Inject target %@ does not exist",_config.inputPath);
            break;
        }
        
        if (!_config.outputPath)
        {
            NSString *fileName = [[_config.inputPath lastPathComponent] stringByDeletingPathExtension];
            _config.outputPath = [[_config.inputPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:[fileName stringByAppendingString:@"_patched"]];
            RSLog(@"Output path is not set, the default path %@",_config.outputPath);
        }
        
        RSTaskResult *taskResult = [NSTask executeWithPath:kMktempPath workingDirectory:nil arguments:@[@"-d",@"-t",kBundleID]];
        
        if (taskResult.status != 0) {
            RSLog(@"Create temp directory failed");
            break;
        }
        
        _tempDirectory = [taskResult.output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        _tempFilePath = [_tempDirectory stringByAppendingPathComponent:[_config.inputPath lastPathComponent]];
        NSError *error;
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:_tempFilePath])
        {
            [[NSFileManager defaultManager] removeItemAtPath:_tempFilePath error:nil];
        }
        
        if(![[NSFileManager defaultManager]copyItemAtPath:_config.inputPath toPath:_tempFilePath error:&error])
        {
            RSLog(@"Error copy file %@ to temp directory %@,%@",_config.inputPath,_tempFilePath,error.localizedDescription);
            break;
        }
        
        if (![self injectAllFiles]) break;
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:_config.outputPath])
        {
            [[NSFileManager defaultManager] removeItemAtPath:_config.outputPath error:nil];
        }
        
        if(![[NSFileManager defaultManager]copyItemAtPath:_tempFilePath toPath:_config.outputPath error:&error])
        {
            RSLog(@"Error copy file %@ to output %@,%@",_tempFilePath,_config.outputPath,error.localizedDescription);
            break;
        }
        
        printf("\e[32mDone, output at %s\e[0m\n",[_config.outputPath UTF8String]);
        [self cleanUpTempDirectory];
        
        return YES;
    } while (0);
    
    printf("\e[31mInject failed\e[0m\n");
    [self cleanUpTempDirectory];
    return NO;
}

- (BOOL)injectAllFiles
{
    for (NSString *file in _config.dylibsWillInject) {
        if(![self injectMachO:_tempFilePath dylibPath:file])
        {
            RSLog(@"Error inject %@ to %@",file,_tempFilePath);
            return NO;
        }
    }
    
    return YES;
}

- (void)cleanUpTempDirectory
{
    if (!_tempDirectory) {
        return;
    }
    
    RSLog(@"Deleting:%@",_tempDirectory);
    NSError *error;
    if(![[NSFileManager defaultManager]removeItemAtPath:_tempDirectory error:&error])
    {
        RSLog(@"Unable to delete temp folder %@",_tempDirectory);
    }
}

- (BOOL)injectArchitecture:(int)fd dylibPath:(NSString *)dylibPath exePath:(NSString *)exePathForInfoOnly
{
    dylibPath = [@"@executable_path" stringByAppendingPathComponent:[dylibPath lastPathComponent]];
    BOOL success = NO;
    
    off_t archPoint = lseek(fd, 0, SEEK_CUR);
    struct mach_header header;
    read(fd, &header, sizeof(header));
    if (header.magic != MH_MAGIC && header.magic != MH_MAGIC_64)
    {
        RSLog(@"Inject failed: Invalid executable %@", exePathForInfoOnly);
        return NO;
    }
    
    if (header.magic == MH_MAGIC_64)
    {
        int delta = sizeof(mach_header_64) - sizeof(mach_header);
        lseek(fd, delta, SEEK_CUR);
    }
    
    char *buffer = (char *)malloc(header.sizeofcmds + 2048);
    read(fd, buffer, header.sizeofcmds);
    
    const char *dylib = dylibPath.UTF8String;
    struct dylib_command *p = (struct dylib_command *)buffer;
    struct dylib_command *last = NULL;
    for (uint32_t i = 0; i < header.ncmds; i++, p = (struct dylib_command *)((char *)p + p->cmdsize))
    {
        if (p->cmd == LC_LOAD_DYLIB || p->cmd == LC_LOAD_WEAK_DYLIB)
        {
            char *name = (char *)p + p->dylib.name.offset;
            if (strcmp(dylib, name) == 0)
            {
                RSLog(@"Already Injected: %@ with %s", exePathForInfoOnly, dylib);
                close(fd);
                return YES;
            }
            last = p;
        }
    }
    
    if ((char *)p - buffer != header.sizeofcmds)
    {
        RSLog(@"LC payload not mismatch: %@", exePathForInfoOnly);
    }
    
    if (last)
    {
        struct dylib_command *inject = (struct dylib_command *)((char *)last + last->cmdsize);
        char *movefrom = (char *)inject;
        uint32_t cmdsize = sizeof(*inject) + (uint32_t)strlen(dylib) + 1;
        cmdsize = (cmdsize + 0x10) & 0xFFFFFFF0;
        char *moveout = (char *)inject + cmdsize;
        for (int i = (int)(header.sizeofcmds - (movefrom - buffer) - 1); i >= 0; i--)
        {
            moveout[i] = movefrom[i];
        }
        memset(inject, 0, cmdsize);
        inject->cmd = LC_LOAD_DYLIB;
        inject->cmdsize = cmdsize;
        inject->dylib.name.offset = sizeof(dylib_command);
        inject->dylib.timestamp = 2;
        inject->dylib.current_version = 0x00000000;
        inject->dylib.compatibility_version = 0x00000000;
        strcpy((char *)inject + inject->dylib.name.offset, dylib);
        
        header.ncmds++;
        header.sizeofcmds += inject->cmdsize;
        lseek(fd, archPoint, SEEK_SET);
        write(fd, &header, sizeof(header));
        
        lseek(fd, archPoint + ((header.magic == MH_MAGIC_64) ? sizeof(mach_header_64) : sizeof(mach_header)), SEEK_SET);
        write(fd, buffer, header.sizeofcmds);
        
        success = YES;
    }
    else
    {
        RSLog(@"Inject failed: No valid LC_LOAD_DYLIB %@", exePathForInfoOnly);
    }
    
    free(buffer);
    
    return success;
}

//
- (BOOL)injectMachO:(NSString *)exePath dylibPath:(NSString *)dylibPath
{
    BOOL success = NO;
    
    int fd = open(exePath.UTF8String, O_RDWR, 0777);
    if (fd < 0)
    {
        RSLog(@"Inject failed: failed to open %@", exePath);
        return NO;
    }
    
    uint32_t magic;
    read(fd, &magic, sizeof(magic));
    if (magic == MH_MAGIC || magic == MH_MAGIC_64)
    {
        lseek(fd, 0, SEEK_SET);
        success = [self injectArchitecture:fd dylibPath:dylibPath exePath:exePath];
    }
    else if (magic == FAT_MAGIC || magic == FAT_CIGAM)
    {
        struct fat_header header;
        lseek(fd, 0, SEEK_SET);
        read(fd, &header, sizeof(fat_header));
        int nArch = header.nfat_arch;
        if (magic == FAT_CIGAM) nArch = [self bigEndianToSmallEndian:header.nfat_arch];
        
        struct fat_arch arch;
        NSMutableArray *offsetArray = [NSMutableArray array];
        for (int i = 0; i < nArch; i++)
        {
            memset(&arch, 0, sizeof(fat_arch));
            read(fd, &arch, sizeof(fat_arch));
            int offset = arch.offset;
            if (magic == FAT_CIGAM) offset = [self bigEndianToSmallEndian:arch.offset];
            [offsetArray addObject:[NSNumber numberWithUnsignedInt:offset]];
        }
        
        for (NSNumber *offsetNum in offsetArray)
        {
            lseek(fd, [offsetNum unsignedIntValue], SEEK_SET);
            success = [self injectArchitecture:fd dylibPath:dylibPath exePath:exePath];
            if (!success) {
                break;
            }
        }
    }
    else
    {
        RSLog(@"Unsupported file with magic number %d",magic);
    }
    
    close(fd);
    
    return success;
}

- (uint32_t)bigEndianToSmallEndian:(uint32_t)bigEndian
{
    uint32_t smallEndian = 0;
    unsigned char *small = (unsigned char *)&smallEndian;
    unsigned char *big = (unsigned char *)&bigEndian;
    for (int i=0; i<4; i++)
    {
        small[i] = big[3-i];
    }
    return smallEndian;
}

@end

