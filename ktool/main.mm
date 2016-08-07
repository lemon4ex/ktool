//
//  main.m
//  resign
//
//  Created by lemon4ex on 16/7/27.
//  Copyright © 2016年 lemon4ex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RSProvisioningProfile.h"
#import "RSResigner.h"
#import "RSInjector.h"
#include <getopt.h>

const char *progname = NULL;

void printInjectorUsage()
{
    printf("Usage: %s inject -p dylibs [-verbose] [-help] input_binary [output_binary]\n",progname);
    printf("\t-p 需要注入到二进制文件的dylib文件，文件可以有多个，使用\",\"分隔\n");
//    printf("\t-input 需要注入dylib的目标二进制文件\n");
    printf("\t-help 显示帮助信息\n");
    printf("\t-verbose 输出debug详细信息\n");
    exit(EXIT_FAILURE);
}

void printResignerUsage()
{
    //resign -verbose -p "pppp" -c "cccc" -i 'iiii' -e 'eeee' -a 'aaaaaa' -m 'mmmm' -n 'nnnn' -N 'NNNN' -v 'vvvv' -V 'VVVV' -input 'input' -output 'output'
    printf("Usage: %s resign -c certNname -m mobileProvision [-p a.dylib,b.dylib...] [-a a.dylib,b.dylib...] [-e entitlements.plist] "
           "[-i bundleIdentifier] [-n bundleName] [-N bundleDisplayName] [-v bundleShortVersion] [-V bundleVersion] [-verbose] [-help] input_file output_file\n",progname);
    printf("\t-c 证书名称，如：iPhone Developer: Xxxxxx Xxxx (*******)\n");
    printf("\t-m mobileProvision文件\n");
    printf("\t-p 需要注入IPA包中二进制文件的dylib文件，可以包含多个，使用\",\"分隔\n");
    printf("\t-a 需要添加到IPA包中的文件，可以包含多个，使用\",\"分隔\n");
    printf("\t-e 签名使用的entitlements.plist文件，如果没有，将使用mobileProvision文件生成\n");
    printf("\t-i Info.plist里的bundleIdentifier\n");
    printf("\t-n Info.plist里的bundleName\n");
    printf("\t-N Info.plist里的bundleDisplayName\n");
    printf("\t-v Info.plist里的bundleShortVersion\n");
    printf("\t-V Info.plist里的bundleVersion\n");
//    printf("\t-input 需要重签名的IPA文件\n");
    printf("\t-help 显示帮助信息\n");
    printf("\t-verbose 输出debug详细信息\n");
    exit(EXIT_FAILURE);
}

void printUsage()
{
    printf("Usage: %s command\n",progname);
    printf("commands are:\n");
    printf("\tresign\tIPA包重签名\n");
    printf("\tinject\t注入dylib到目标二进制文件中\n");
    exit(EXIT_FAILURE);
}

#define CHECK_MISSING_ARGS() \
if (i + 1 == argc) {\
printf("missing argument(s) to %s option", argv[i]);\
printUsage();\
}\

#define CHECK_INJIECTOR_MISSING_ARGS() \
if (i + 1 == argc) {\
printf("missing argument(s) to %s option", argv[i]);\
printInjectorUsage();\
}\

#define CHECK_RESIGNER_MISSING_ARGS() \
if (i + 1 == argc) {\
printf("missing argument(s) to %s option", argv[i]);\
printResignerUsage();\
}\

void processorInject(int argc,const char * argv[]);
void processorResiner(int argc,const char * argv[]);

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        progname = argv[0];
        
        if (argc < 2) {
            printUsage();
        }
        
        if (strncmp(argv[1], "inject", sizeof("inject") - 1) == 0) {
            processorInject(argc, argv);
        }
        else if (strncmp(argv[1], "resign", strlen("resign")) == 0)
        {
            processorResiner(argc, argv);
        }
        else
        {
            printUsage();
        }
        
    }
    return 0;
}

void processorInject(int argc,const char * argv[])
{
    if (argc < 5) {
        printInjectorUsage();
    }
    
    RSInjectorConfig *config = [[RSInjectorConfig alloc]init];
    for(int i = 2 ;i < argc; ++i)
    {
        if (argv[i][0] == '-') {
            if (argv[i][1] == 'p' && argv[i][2] == '\0') {
                CHECK_INJIECTOR_MISSING_ARGS()
                config.dylibsWillInject = [[NSString stringWithUTF8String:argv[++i]] componentsSeparatedByString:@","];
            }
            else if (strcmp(argv[i], "-verbose") == 0)
            {
                config.debugFlag = YES;
            }
            else
            {
                printInjectorUsage();
            }
        }
        else
        {
            if (strcmp(argv[i], "-help") == 0)
            {
                printInjectorUsage();
            }
            else if (!config.inputPath) {
                config.inputPath = [NSString stringWithUTF8String:argv[i]];
            }
            else if (!config.outputPath)
            {
                config.outputPath = [NSString stringWithUTF8String:argv[i]];
            }
            else
            {
                printInjectorUsage();
            }
            
        }
    }
    
    printf("\n");
    RSInjector *injector = [[RSInjector alloc]init];
    [injector injectWithConfig:config];
    printf("\n");
}

void processorResiner(int argc,const char * argv[])
{
    if (argc < 8) {
        printResignerUsage();
    }
    
    RSResignerConfig *config = [[RSResignerConfig alloc]init];
    for(int i = 2 ;i < argc; ++i)
    {
        if (argv[i][0] == '-' && argv[i][2] == '\0') {
            switch (argv[i][1]) {
                case 'p':
                {
                    CHECK_RESIGNER_MISSING_ARGS()
                    config.dylibsWillInject = [[NSString stringWithUTF8String:argv[++i]] componentsSeparatedByString:@","];
                }
                    break;
                case 'c':
                {
                    CHECK_RESIGNER_MISSING_ARGS()
                    config.certName = [NSString stringWithUTF8String:argv[++i]];
                }
                    break;
                case 'm':
                {
                    CHECK_RESIGNER_MISSING_ARGS()
                    config.mobileProvisionPath = [NSString stringWithUTF8String:argv[++i]];
                }
                    break;
                case 'i':
                {
                    CHECK_RESIGNER_MISSING_ARGS()
                    config.bundleIdentifier = [NSString stringWithUTF8String:argv[++i]];
                }
                    break;
                case 'n':
                {
                    CHECK_RESIGNER_MISSING_ARGS()
                    config.bundleName = [NSString stringWithUTF8String:argv[++i]];
                }
                    break;
                case 'N':
                {
                    CHECK_RESIGNER_MISSING_ARGS()
                    config.bundleDisplayName = [NSString stringWithUTF8String:argv[++i]];
                }
                    break;
                case 'v':
                {
                    CHECK_RESIGNER_MISSING_ARGS()
                    config.bundleShortVersion = [NSString stringWithUTF8String:argv[++i]];
                }
                    break;
                case 'V':
                {
                    CHECK_RESIGNER_MISSING_ARGS()
                    config.bundleVersion = [NSString stringWithUTF8String:argv[++i]];
                }
                    break;
                case 'a':
                {
                    CHECK_RESIGNER_MISSING_ARGS()
                    config.filesWillAdd = [[NSString stringWithUTF8String:argv[++i]] componentsSeparatedByString:@","];
                }
                    break;
                case 'e':
                {
                    CHECK_RESIGNER_MISSING_ARGS()
                    config.entitlementsPlistPath = [NSString stringWithUTF8String:argv[++i]];
                }
                    break;
                default:
                {
                    printResignerUsage();
                }
                    break;
            }
        }
        else
        {
            if (strcmp(argv[i], "-help") == 0)
            {
                printResignerUsage();
            }
            else if (strcmp(argv[i], "-verbose") == 0)
            {
                config.debugFlag = YES;
            }
            else
            {
                if (!config.inputPath) {
                    config.inputPath = [NSString stringWithUTF8String:argv[i]];
                }
                else if (!config.outputPath)
                {
                    config.outputPath = [NSString stringWithUTF8String:argv[i]];
                }
                else
                {
                    printResignerUsage();
                }
            }
        }
    }
    
    printf("\n");
    RSResigner *resigner = [[RSResigner alloc]init];
    [resigner resignWithConfig:config];
    printf("\n");
    
}
