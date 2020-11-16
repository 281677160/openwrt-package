## 简介

在 [zxlhhyccc/Hill-98-k3screenctrl](https://github.com/zxlhhyccc/Hill-98-k3screenctrl) 已经给K3屏幕开启了7屏的基础上，使用 [K3 openwrt18.06.02](https://www.right.com.cn/forum/thread-466672-1-1.html) 固件中的```/lib/k3screenctrl/```下的sh文件做了替换

搭配的 luci-app 是根据固件的LuCi文件修改的 [lwz322/luci-app-k3screenctrl](https://github.com/lwz322/luci-app-k3screenctrl)

最后使用修改自 [lean/lede](https://github.com/lean/lede) 中的编译文件 [k3screenctrl_build](https://github.com/lwz322/k3screenctrl_build) 编译

**2020.9.17 TARGET依赖导致menuconfig不显示的兼容** ：详见[k3screenctrl_build](https://github.com/lwz322/k3screenctrl_build)的README

**2020.3.14 睡死问题的修复进展** ：[尝试修复屏幕驱动睡死的问题](https://www.right.com.cn/forum/thread-3174657-1-1.html)对睡死问题在逐步跟进和修复，修复这个问题或许就差几个反馈

具体进展可见于[likanchen/k3screenctrl](https://github.com/likanchen/k3screenctrl)，编译固件时也可以尝试替换，希望有这方面问题的同学可以积极测试和反馈，一起完善K3的OpenWrt

**2020.3.13 脚本arp命令报错** ：对[报错](https://www.right.com.cn/forum/forum.php?mod=redirect&goto=findpost&ptid=729670&pid=8029524)，调查了下应该是历史遗留问题

OpenWrt早先时候（k3screenctrl的开发时间是2017年）的arp命令对应一个程序，现在版本只是定义在/etc/profile的一个函数，即登陆shell的环境变量中的函数，故单独运行脚本就会报错，然而这个不影响k3screenctrl的正常输出，理论上注释也不影响

**2020.2.15 屏幕睡死问题**：总算是接到反馈，亲眼见到了屏幕睡死的表现
- 黑屏，触摸无响应
- 进程并没有被终止（也就不是靠添加守护进程就能解决）
- 负载处于正常范围内，网络路由功能也是正常的

所以，暂时没有什么特别有效的方法，只能重启k3screenctrl临时恢复屏幕功能；K3的屏幕固然鸡肋，但是解决问题是趋势所向，在readme后段提供了个人已知的k3screenctrl的信息，如果有修复的案例，欢迎反馈

**2020.1.31 天气API的问题**：[已知的一个致命问题](https://www.right.com.cn/forum/thread-2068254-1-1.html)
> 屏幕会隔三差五的睡死，睡死时候，网路会出异常，变得非常慢，检查系统日志，会发现k3screenctrl大量的错误信息。硬重启后恢复正常。软重启无法激活屏幕。
> 所有带k3screenctrl的固件都有睡死问题，据说是天气API导致的。但是也有人说一切正常，所以真实原因，自己刷了才知道

考虑到作为路由器还是要稳定性优先的，所以尽可能排除不稳定因素，参考了下[ K3 OpenWrt固件（更新日期 2020.1.30）](https://www.right.com.cn/forum/thread-2512521-1-1.html)，决定本仓库的代码默认不再自带天气的私钥，默认不再开启天气更新（更新间隔设置为0，脚本不运行），有需求可以自行申请[心知天气](https://www.seniverse.com/)的API或者下载已经提供了API Key的固件；

## 屏幕界面
基本情况可以参考下图：

![](https://img.vim-cn.com/f7/53d38adeae90d86c1c94e757ecf18a872af9bc.png)

- 第一屏：升级界面
- 第二屏：型号(硬件版本型号H/W全部显示为A1)，MAC，软件版本
- 第三屏：USB与网口接入情况
- 第四屏：网速以及2.4G和5G WiFi的接入客户端数量
- 第五屏：天气，时间
- 第六屏：WiFi信息：SSID和密码（可选隐藏）
- 第七屏：已接入终端和网速（只统计IPv4转发）

上面主要是接近官方固件的屏幕信息显示，针对新版本通过修改脚本，添加了在前两屏更多信息的显示的选项，默认开启，如下

![](https://img.vim-cn.com/91/4a753ea2b240b547f2a2ee2a62697e27433c62.png)

- **U:0.14 R:8%**：CPU负载 内存占用百分比（和第二屏的软件版本显示的一样）
- **up 10:47**：运行时间
- **H/W: 48*C**：CPU温度
- **MAC地址: OpenWrt 19.07.0**：系统版本号

## 已知问题

- 部分设备的屏幕在使用本软件后无法正常显示界面，可能是屏幕本身的固件版本较低，可以通过刷较新版本的官方/官改固件对屏幕固件升级
- 部分设备存在屏幕睡死的问题，具体表现为黑屏状态下触摸无反应
- 依靠IP定位偶尔可能无法定位到准确的城市，进而无法自动查询天气，建议关闭IP定位，手动指定城市
- WiFi信息部分的访客网络信息，OpenWrt官方没有访客网络的APP，也就没有标准一说，脚本中的设置貌似不适合添加SSID访客网络的做法
- 在开启硬件转发加速（HWNAT或者offload）的情况下，iptable无法统计流量

## SDK编译
因为在k3screenctrl的Makefile文件中有对机型的要求的倚赖，所以使用SDK单独编译k3screenctrl时，k3screenctrl不会被编译

具体也就是k3screenctrl_build文件中的DEPENDS：
```makefile
define Package/k3screenctrl
  SECTION:=utils
  CATEGORY:=Utilities
  DEPENDS:=@TARGET_bcm53xx_DEVICE_phicomm-k3 +@KERNEL_DEVMEM +coreutils +coreutils-od +bash +curl
  TITLE:=LCD screen controller on PHICOMM K3
  URL:=https://github.com/lwz322/k3screenctrl.git
endef
```
解决办法：去掉depends中的```=@TARGET_bcm53xx_DEVICE_phicomm-k3 +@KERNEL_DEVMEM ```

## 可以公开的情报

最早要追溯到2017年updateing的[【测试】K3 的 LEDE（更新部分屏幕支持）](https://koolshare.cn/thread-91998-1-1.html)，最主要的是逆向做出了[k3screenctrl](https://github.com/updateing/k3screenctrl)，使得屏幕显示有了开源支持；另外作者在2019年也更新了屏幕固件更新的代码，[CCluv/k3screenctrl](https://github.com/CCluv/k3screenctrl)提供了屏幕固件的文件

1. 所有代码的基础：
   
   - [[2019-01-21]K3补丁已经提交合并到OpenWrt官方源码，附加自编译说明](https://www.right.com.cn/forum/thread-419328-1-1.html)，K3补丁（基于updateing的创始代码）。补丁继承了LCD屏幕接口，增加了对USB3.0的支持
   
   - 2018.5 [Hill-98/luci-app-k3screenctrl](https://github.com/Hill-98/luci-app-k3screenctrl)添加了网页设置的支持
   
   - [[2019.03.26更新]K3 openwrt18.06.02 完美适配屏幕天气页](https://www.right.com.cn/forum/thread-466672-1-1.html)，应该是天气显示支持的开端，我的仓库中的sh文件基于此修改，结合了在Github上找到的可能的开源实现[zxlhhyccc/Hill-98-k3screenctrl](https://github.com/zxlhhyccc/Hill-98-k3screenctrl)
   
     > 修复因天气api超时导致程序进程卡死屏幕黑屏的问题， 不保证API的稳定可用
     >
     > 因为自动识别天气城市的api用的阿里的一个api,最近抽风，脚本里没有超时设置，会导致进程卡死，屏幕会有错误或黑屏的问题，可以通过手动指定城市解决，有能力的自己改下脚本设置一下超时，后面有时间修复
     >
     > 屏幕显示天气要以前刷过新版官方或官改固件，屏幕固件是新版的才行
   
2. 指出问题：

   - [2019-10-21斐讯 K3 屏幕控制程序升级版 【6个页面】MAC显示修复 长按脚本](https://www.right.com.cn/forum/thread-1247520-1-1.html)，github内附了最详细的技术[readme](https://github.com/lanceliao/k3screenctrl)

   - [（2020-1-8）netflixcn的裴讯 K3 OpenWrt LEDE刷机固件](https://www.right.com.cn/forum/thread-2068254-1-1.html)，k3的openwrt固件中用户最多的一个？也是直接指出了问题

     > 已知的一个致命问题: 屏幕会隔三差五的睡死，睡死时候，网路会出异常，变得非常慢，检查系统日志，会发现[k3screenctrl](https://github.com/lwz322/luci-app-k3screenctrl)大量的错误信息。硬重启后恢复正常。软重启无法激活屏幕。
     >
     > 所有带[k3screenctrl](https://github.com/lwz322/luci-app-k3screenctrl)的固件都有睡死问题，据说是天气API导致的。但是也有人说一切正常，所以真实原因，自己刷了才知道。

    - [关于K3屏幕睡死问题](https://www.right.com.cn/forum/thread-2712963-1-1.html)
     > 屏幕过一段时间会睡死，关了天气更新都会。。但路由功能正常的。。。

## En

On the basic of [zxlhhyccc/Hill-98-k3screenctrl](https://github.com/zxlhhyccc/Hill-98-k3screenctrl)，added .sh file from [K3 openwrt18.06.02](https://www.right.com.cn/forum/thread-466672-1-1.html)，It works fine with [lwz322/luci-app-k3screenctrl](https://github.com/lwz322/luci-app-k3screenctrl) &
[k3screenctrl_build](https://github.com/lwz322/k3screenctrl_build) (from[lean/lede](https://github.com/lean/lede))

## Screen Interface
New Version add additional info display, including: CPU temprature, Load, RAM, uptime, etc

1. Update
2. Model, Version, CPU Temp, MAC
3. Port
4. Speed, WiFi (2.4G/5G client) Assicated
5. Weather, Date and Time
6. WiFi Info:SSID & Password (suppressible)
7. Client speed (IPv4 Forward only)
