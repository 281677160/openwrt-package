# luci-app-jd-dailybonus
Luci for JD dailybonus Script for Openwrt  
一个运行在openwrt下的京东签到插件。

### Update Log 2020-10-21  

#### Updates

- UPD: 精简微信推送内容，更加直观。


详情见[具体日志](./relnotes.txt)。 

### 介绍

使用NobyDa “京东多合一签到脚本”为基础，移植到openwrt实现。  

### 如何使用

假设你的lean openwrt（最新版本19.07） 在 lede 目录下
```
cd lede/package/lean/  

git clone https://github.com/jerrykuku/luci-app-jd-dailybonus.git  

make menuconfig #Check LUCI->Applications->luci-app-jd-dailybonus

make package/lean/luci-app-jd-dailybonus/compile V=s  #单独编译luci-app-jd-dailybonus  

make -j1 V=s #编译固件
```

### 如何安装

🛑 [点击这里去下载最新的版本](https://github.com/jerrykuku/luci-app-jd-dailybonus/releases)

⚠️安装步骤[重要]⚠️  

1.自行安装Node [命令: opkg update && opkg install node]
  (如果已经安装node版本的网易云插件则可以跳过)   
  
2.安装luci-app-jd-dailybonus

### 感谢

感谢[NobyDa](https://github.com/NobyDa) 的脚本。  

### 我的其它项目
Argon theme ：https://github.com/jerrykuku/luci-theme-argon  
Argon theme config  ：https://github.com/jerrykuku/luci-app-argon-config
Hello World ：https://github.com/jerrykuku/luci-app-vssr  
openwrt-nanopi-r1s-h5 ： https://github.com/jerrykuku/openwrt-nanopi-r1s-h5  
