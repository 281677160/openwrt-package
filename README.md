# [[281677160/AutoBuild-OpenWrt的专用软件包](https://github.com/281677160/AutoBuild-OpenWrt)]

#
#### 分支[master]的为lede源码专用，分支[19.07]的为lienol源码专用
#

##### 添加以下插件
###### [luci-app-adguardhome](#/README.md)
###### [luci-app-advancedsetting](#/README.md)
###### [luci-app-aliddns](#/README.md)]
###### [luci-app-argon-config](#/README.md)
###### [luci-app-autotimeset](#/README.md)
###### [luci-app-clash](#/README.md)
###### [luci-app-control-timewol](#/README.md)
###### [luci-app-control-webrestriction](#/README.md)
###### [luci-app-control-weburl](#/README.md)
###### [luci-app-cpulimit](#/README.md)
###### [luci-app-ddnsto](#/README.md)
###### [luci-app-dnsfilter](#/README.md)
###### [luci-app-eqos](#/README.md)
###### [luci-app-filebrowser](#/README.md)
###### [luci-app-godproxy](#/README.md)
###### [luci-app-gost](#/README.md)
###### [luci-app-gowebdav](#/README.md)
###### [luci-app-ipsec-vpnserver-manyusers](#/README.md)
###### [luci-app-iptvhelper](#/README.md)
###### [luci-app-k3screenctrl](#/README.md)
###### [luci-app-linkease](#/README.md)
###### [luci-app-mentohust](#/README.md)
###### [luci-app-netdata](#/README.md)
###### [luci-app-netkeeper-interception](#/README.md)
###### [luci-app-oaf](#/README.md)
###### [luci-app-onliner](#/README.md)
###### [luci-app-oscam](#/README.md)
###### [luci-app-poweroff](#/README.md)
###### [luci-app-pptp-vpnserver-manyusers](#/README.md)
###### [luci-app-pushbot](#/README.md)
###### [luci-app-serverchan](#/README.md)
###### [luci-app-smartdns](#/README.md)
###### [luci-app-smartinfo](#/README.md)
###### [luci-app-socat](#/README.md)
###### [luci-app-syncthing](#/README.md)
###### [luci-app-tencentddns](#/README.md)
###### [luci-app-ttnode](#/README.md)
###### [luci-app-vssr](#/README.md)
###### [luci-theme-argon](#/README.md)
###### [luci-theme-atmaterial](#/README.md)
###### [luci-theme-edge](#/README.md)
###### [luci-theme-opentomato](#/README.md)
###### [luci-theme-opentomcat](#/README.md)
###### [luci-theme-rosy](#/README.md)
#

#

- 编译luci-app-advanced时候自动带上luci-app-filebrowser ，高级设置+文件浏览器（文件管理），所以luci-app-advanced和luci-app-filebrowser不能同时编译，只能二选一

- luci-app-samba 和 luci-app-samba4 不能同时编译，同时编译会失败
- 想选择luci-app-samba4，首先在Extra packages ---> 把autosamba取消，在选择插件的那里把luci-app-samba取消，然后在Network ---> 把 samba36-server取消，最后选择luci-app-samba4，记得顺序别搞错

- luci-app-dockerman 和 luci-app-docker 不能同时编译，同时编译会编译失败
- 编译luci-app-dockerman或者luci-app-docker，首先要在Global build settings ---> Enable IPv6 support in packages (NEW)（选上）

- luci-app-autotimeset 和 luci-app-autoreboot 不能同时编译，同时编译会编译失败

- luci-app-ddnsto  如果有兼容性问题，安装好固件后执行 `/etc/init.d/ddnsto enable` 命令

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
