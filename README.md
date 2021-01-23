# [[281677160/build-openwrt的专用软件包](https://github.com/281677160/build-openwrt.git)]

#
#### 分支[master]的为lede源码专用，分支[19.07]的为lienol源码专用，分支[project-18.06]的为project源码专用
#

##### 添加以下插件
###### [luci-theme-rosy](#/README.md)    &nbsp;&nbsp;&nbsp;&nbsp;#主题-rosy
###### [luci-theme-edge](#/README.md)   &nbsp;&nbsp;&nbsp;&nbsp;#主题-edge
###### [luci-theme-opentomcat](#/README.md)  &nbsp;&nbsp;&nbsp;&nbsp;#主题-opentomcat
###### [luci-theme-opentopd](#/README.md)  &nbsp;&nbsp;&nbsp;&nbsp;#主题-opentopd<br>
###### [luci-theme-atmaterial](#/README.md)  &nbsp;&nbsp;&nbsp;&nbsp;#atmaterial-主题<br>
###### [luci-theme-rosy](#/README.md)   &nbsp;&nbsp;&nbsp;&nbsp;#主题-rosy<br>
###### [luci-theme-infinityfreedom](#/README.md)   &nbsp;&nbsp;&nbsp;&nbsp;#透明主题<br>
###### [luci-app-openclash](#/README.md)    &nbsp;&nbsp;&nbsp;&nbsp;#openclash 出国软件<br>
###### [luci-app-clash](#/README.md)    &nbsp;&nbsp;&nbsp;&nbsp;#clash 出国软件<br>
###### [luci-app-serverchan](#/README.md)    &nbsp;&nbsp;&nbsp;&nbsp;#微信推送<br>
###### [luci-app-eqos](#/README.md)   &nbsp;&nbsp;&nbsp;&nbsp;#内网控速 内网IP限速工具<br>
###### [luci-app-jd-dailybonus](#/README.md)    &nbsp;&nbsp;&nbsp;&nbsp;#京东签到<br>
###### [luci-app-passwall](#/README.md)    &nbsp;&nbsp;&nbsp;&nbsp;#passwall 出国软件<br>
###### [luci-app-advanced](#/README.md)   &nbsp;&nbsp;&nbsp;&nbsp;#[luci-app-advanced&nbsp;高级设置&nbsp;+&nbsp;luci-app-filebrowser&nbsp;文件浏览器（文件管理）](#/README.md)，luci-app-advanced和luci-app-filebrowser不能同时编译<br>
###### [luci-app-poweroff](#/README.md)    &nbsp;&nbsp;&nbsp;&nbsp;#关机（增加关机功能）<br>
###### [luci-theme-argon](#/README.md)   &nbsp;&nbsp;&nbsp;&nbsp;#新的argon主题<br>
###### [luci-app-argon-config](#/README.md)    &nbsp;&nbsp;&nbsp;&nbsp;#argon主题设置（编译时候选上,在固件的‘系统’里面）<br>
###### [luci-app-k3screenctrl](#/README.md)   &nbsp;&nbsp;&nbsp;&nbsp;#k3屏幕，k3路由器专用<br>
###### [luci-app-koolproxyR](#/README.md)   &nbsp;&nbsp;&nbsp;&nbsp;#广告过滤大师 plus+  ，慎用，不懂的话，打开就没网络了<br>
###### [luci-app-oaf （OpenAppFilter）](#/README.md)  &nbsp;&nbsp;&nbsp;&nbsp;#应用过滤 ，该模块只工作在路由模式， 旁路模式、桥模式不生效，还有和Turbo ACC 网络加速有冲突<br>
###### [luci-app-ssr-plus](#/README.md)   &nbsp;&nbsp;&nbsp;&nbsp;#shadowsocksR Puls+  出国软件<br>
###### [luci-app-vssr](#/README.md)   &nbsp;&nbsp;&nbsp;&nbsp;#Hello World 也叫彩旗飘飘  出国软件<br>
###### [luci-app-gost](#/README.md)   &nbsp;&nbsp;&nbsp;&nbsp;#GO语言实现的安全隧道<br>
###### [luci-app-cpulimit](#/README.md)   &nbsp;&nbsp;&nbsp;&nbsp;#CPU性能限制<br>
###### [luci-app-wrtbwmon-zhcn](#/README.md)   &nbsp;&nbsp;&nbsp;&nbsp;#流量统计，替代luci-app-wrtbwmon，在固件状态栏显示，[不能同时编译](#/README.md)<br>
###### [luci-app-autopoweroff](#/README.md)   &nbsp;&nbsp;&nbsp;&nbsp;#定时自动关机，替代luci-app-autoreboot，[不能同时编译](#/README.md) <br>
###### [luci-app-control-webrestriction](#/README.md)   &nbsp;&nbsp;&nbsp;&nbsp;#访问限制<br>
###### [luci-app-control-weburl](#/README.md)   &nbsp;&nbsp;&nbsp;&nbsp;#网址过滤<br>
###### [luci-app-modeminfo](#/README.md)    &nbsp;&nbsp;&nbsp;&nbsp;#OpenWrt LuCi的3G / LTE加密狗信息<br>
###### [luci-app-gowebdav](#/README.md)   &nbsp;&nbsp;&nbsp;&nbsp;#GoWebDav 是一个轻巧、简单、快速的 WebDav 服务端程序<br>
###### [luci-app-smartinfo](#/README.md)   &nbsp;&nbsp;&nbsp;&nbsp;#磁盘监控 ，该工具帮助您通过S.M.A.R.T技术来监控您硬盘的健康状况<br>
###### [luci-app-pptp-vpnserver-manyusers](#/README.md)   &nbsp;&nbsp;&nbsp;&nbsp;#PPTP VPN 服务器
###### [luci-app-smartdns](#/README.md)   &nbsp;&nbsp;&nbsp;&nbsp;#smartdns DNS加速<br>
###### [luci-app-mentohust](#/README.md)   &nbsp;&nbsp;&nbsp;&nbsp;#MentoHUST 的 LuCI 控制界面<br>
###### [luci-app-adguardhome](#/README.md)   &nbsp;&nbsp;&nbsp;&nbsp;#adguardhome<br>
###### [luci-app-dockerman](#/README.md)   &nbsp;&nbsp;&nbsp;&nbsp;#docker容器，和源码自带的luci-app-docker[不能同时编译](#/README.md)，同时编译会失败，所以要注意<br>
###### [luci-app-syncthing](#/README.md)   &nbsp;&nbsp;&nbsp;&nbsp;#Syncthing是一个连续的文件同步程序。它在两台或多台计算机之间同步文件
###### [luci-app-dnsfilter](#/README.md)    &nbsp;&nbsp;&nbsp;&nbsp;#广告过滤，支持 AdGuardHome/Host/DNSMASQ/Domain 格式的规则订阅
###### [luci-app-tencentddns](#/README.md)    &nbsp;&nbsp;&nbsp;&nbsp;#腾讯DDNS


#

- 编译luci-app-advanced时候自动带上luci-app-filebrowser ，高级设置+文件浏览器（文件管理），所以luci-app-advanced和luci-app-filebrowser不能同时编译，只能二选一

- luci-app-samba 和 luci-app-samba4 不能同时编译，同时编译会失败
- 想选择luci-app-samba4，首先在Extra packages ---> 把autosamba取消，在选择插件的那里把luci-app-samba取消，然后在Network ---> 把 samba36-server取消，最后选择luci-app-samba4，记得顺序别搞错

- luci-app-dockerman 和 luci-app-docker 不能同时编译，同时编译会编译失败
- 编译luci-app-dockerman或者luci-app-docker，首先要在Global build settings ---> Enable IPv6 support in packages (NEW)（选上）

- luci-app-wrtbwmon 和 luci-app-wrtbwmon-zhcn 不能同时编译，同时编译会编译失败

- luci-app-autopoweroff 和 luci-app-autoreboot 不能同时编译，同时编译会编译失败
#
#
##### 如果还是没有你需要的插件，请不要一下子就拉取别人的插件包
##### 相同的文件都拉一起，因为有一些可能还是其他大神修改过的容易造成编译错误的
##### 想要什么插件就单独的拉取什么插件就好，或者告诉我，我把插件放我的插件包就行了
##### 《[单独拉取插件说明](https://github.com/danshui-git/shuoming/blob/master/ming.md)》 ，里面包含各种命令简单说明
#
#
## 感谢各位大神的源码，openwrt有各位大神而精彩，感谢！感谢！，插件每天白天12点跟晚上12点都同步一次各位大神的源码！

#

# 请不要Fork此仓库，你Fork后，插件不会自动根据作者更新而更新!!!!!!!!!!!
