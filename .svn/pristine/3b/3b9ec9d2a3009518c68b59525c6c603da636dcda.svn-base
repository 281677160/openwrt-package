### openwrt-nanopi-r1s-h5 移植openwrt 到 Nanopi r1s h5 

#### Intro
此项目是移植openwrt（非friendlyWRT）到  Nanopi r1s h5  适配lean openwrt
<img src="https://raw.githubusercontent.com/jerrykuku/staff/master/Snipaste_2020-01-05_22-30-01.jpg" >
#### Usage
1. git clone https://github.com/jerrykuku/openwrt-nanopi-r1s-h5.git 到本地
2. 将下载下来的目录覆盖到lean 源码（目录已经对应） 可以直接cp -r 
同时记住给target\linux\sunxi\base-files\etc\board.d\01_leds 赋予可执行权限 0755
3. 执行make menuconfig
4. target 选择 nanopi r1s h5
5. make -j1 V=s

#### 已知的问题
1. 生成的固件，外壳上的 LAN WAN口将会对调 即：原生G口为LAN口 USB->8153B的G口为WAN。
2. 目前无wifi支持。  如果你有方法可以驱动wifi 欢迎提交方法

#### 支持我
如果你觉得我做的不错，可以赞赏一下。
<img src="https://raw.githubusercontent.com/jerrykuku/staff/master/photo_2019-12-22_11-40-20.jpg" width="300" height="300">
