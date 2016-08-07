//
//  RSConfig.h
//  resign
//
//  Created by lemon4ex on 16/7/31.
//  Copyright © 2016年 lemon4ex. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RSConfig : NSObject
//@property (nonatomic, copy) NSString *command; ///< 打包命令
@property (nonatomic, assign) BOOL debugFlag; ///< -d 是否显示调试信息
@property (nonatomic, assign) BOOL IFlag; ///< -I 是否进入交互模式
@property (nonatomic, assign) BOOL hFlag; ///< -h 显示帮助信息
//@property (nonatomic, assign) BOOL versionFlag; ///< -V 显示版本信息
@property (nonatomic, copy) NSString *inputPath; ///< 输入文件路径
@property (nonatomic, copy) NSString *outputPath; ///< 输出文件路径
@end
