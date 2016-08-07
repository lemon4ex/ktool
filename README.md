# ktool
一个包含iPA重签名以及dylib注入的命令行工具

## 用法

```bash
ktool command
commands are:
	resign	IPA包重签名
	inject	注入dylib到目标二进制文件中
```

## 重签名

```bash
ktool resign -c certNname -m mobileProvision [-p a.dylib,b.dylib...] [-a a.dylib,b.dylib...] [-e entitlements.plist] [-i bundleIdentifier] [-n bundleName] [-N bundleDisplayName] [-v bundleShortVersion] [-V bundleVersion] [-verbose] [-help] input_file output_file
	-c 证书名称，如：iPhone Developer: Xxxxxx Xxxx (*******)
	-m mobileProvision文件
	-p 需要注入IPA包中二进制文件的dylib文件，可以包含多个，使用","分隔
	-a 需要添加到IPA包中的文件，可以包含多个，使用","分隔
	-e 签名使用的entitlements.plist文件，如果没有，将使用mobileProvision文件生成
	-i Info.plist里的bundleIdentifier
	-n Info.plist里的bundleName
	-N Info.plist里的bundleDisplayName
	-v Info.plist里的bundleShortVersion
	-V Info.plist里的bundleVersion
	-help 显示帮助信息
	-verbose 输出debug详细信息
```

## dylib注入

```bash
ktool inject -p dylibs [-verbose] [-help] input_binary [output_binary]
    -p 需要注入到二进制文件的dylib文件，文件可以有多个，使用","分隔
	-help 显示帮助信息
	-verbose 输出debug详细信息
```

## 联系
[@lemon4ex](http://weibo.com/lemon4ex)

[admin@aigudao.net](mailto:admin@aigudao.net)

[http://aigudao.net](http://aigudao.net)