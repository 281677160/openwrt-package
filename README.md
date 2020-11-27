# [[281677160/build-openwrt的专用软件包](https://github.com/281677160/build-openwrt.git)]

#
#### 分支[master]的为lede源码专用，分支[19.07]的为lienol源码专用，分支[project-18.06]的为project源码专用
#

##### 添加以下插件
###### luci-theme-rosy    #主题-rosy
###### luci-theme-edge    #主题-edge
###### luci-theme-opentomcat   #主题-opentomcat
###### luci-theme-opentopd   #主题-opentopd<br>
###### luci-theme-atmaterial   #atmaterial-主题<br>
###### luci-theme-rosy   #主题-rosy<br>
###### luci-theme-infinityfreedom    #透明主题<br>
###### luci-app-openclash    #openclash 出国软件<br>
###### luci-app-clash    #clash 出国软件<br>
###### luci-app-serverchan    #微信推送<br>
###### luci-app-eqos    #内网控速 内网IP限速工具<br>
###### luci-app-jd-dailybonus    #京东签到<br>
###### luci-app-passwall    #passwall 出国软件<br>
###### luci-app-poweroff    #关机（增加关机功能）<br>
###### luci-theme-argon    #新的argon主题<br>
###### luci-app-argon-config    #argon主题设置（编译时候选上,在固件的‘系统’里面）<br>
###### luci-app-k3screenctrl   #k3屏幕，k3路由器专用<br>
###### luci-app-koolproxyR   #广告过滤大师 plus+  ，慎用，不懂的话，打开就没网络了<br>
###### luci-app-oaf （OpenAppFilter）  #应用过滤 ，该模块只工作在路由模式， 旁路模式、桥模式不生效，还有和Turbo ACC 网络加速有冲突<br>
###### luci-app-ssr-plus   #shadowsocksR Puls+  出国软件<br>
###### luci-app-vssr   #Hello World 也叫彩旗飘飘  出国软件<br>
###### luci-app-gost   #GO语言实现的安全隧道<br>
###### luci-app-cpulimit   #CPU性能限制<br>
###### luci-app-wrtbwmon-zhcn   #流量统计，替代luci-app-wrtbwmon，在固件状态栏显示<br>
###### luci-app-autopoweroff   #定时设置，替代luci-app-autoreboot<br>
###### luci-app-control-webrestriction   #访问限制<br>
###### luci-app-control-weburl   #网址过滤<br>
###### luci-app-control-timewol   #定时唤醒<br>
###### luci-app-pptp-vpnserver-manyusers   #PPTP VPN 服务器
###### luci-app-smartdns   #smartdns DNS加速<br>
###### luci-app-adguardhome   #adguardhome<br>
###### luci-app-dockerman   #docker容器，和源码自带的luci-app-docker不能同时编译，同时编译会失败，所有要注意<br>

#
#
#
##### 如果还是没有你需要的插件，请不要一下子就拉取别人的插件包
##### 相同的文件都拉一起，因为有一些可能还是其他大神修改过的容易造成编译错误的
##### 想要什么插件就单独的拉取什么插件就好，或者告诉我，我把插件放我的插件包就行了
#
#
## 感谢各位大神的源码，openwrt有各位大神而精彩，感谢！感谢！，插件每天白天12点跟晚上12点都同步一次各位大神的源码！

#

# 请不要Fork此仓库，你Fork后，插件不会自动根据作者更新而更新!!!!!!!!!!!
