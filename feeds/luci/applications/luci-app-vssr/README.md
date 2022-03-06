<div align="center">
  <img src="https://raw.githubusercontent.com/jerrykuku/staff/master/Helloworld_title.png"  >
  <h1 align="center">
    An openwrt Internet surfing plug-in
  </h1>
    <h3 align="center">
    HelloWorld是一个以用户最佳主观体验为导向的插件，它支持多种主流协议和多种自定义视频分流服务，拥有精美的操作界面，并配上直观的节点信息。<br><br>
  </h3>

  <a href="/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-brightgreen.svg" alt="">
  </a>

  <a href="https://github.com/jerrykuku/luci-app-vssr/pulls">
    <img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg" alt="">
  </a>

  <a href="https://github.com/jerrykuku/luci-app-vssr/issues/new">
    <img src="https://img.shields.io/badge/Issues-welcome-brightgreen.svg">
  </a>

  <a href="https://github.com/jerrykuku/luci-app-vssr/releases">
    <img src="https://img.shields.io/badge/release-v1.22-blue.svg?">
  </a>

  <a href="https://github.com/jerrykuku/luci-app-vssr/releases">
    <img src="https://img.shields.io/github/downloads/jerrykuku/luci-app-vssr/total">
  </a>

  <a href="https://t.me/PIN1Group">
    <img src="https://img.shields.io/badge/Contact-telegram-blue">
  </a>
</div>

<b><br>支持全部类型的节点分流</b>  
目前只适配最新版 argon主题 （其他主题下应该也可以用 但显示应该不会很完美）  
目前Lean最新版本的openwrt 已经可以直接拉取源码到 package/lean 下直接进行勾选并编译。  


### 更新日志 2022-01-08  v1.23
- FIX: 增强订阅节点时旗帜匹配的准确性。


详情见[具体日志](./relnotes.txt)。 

### 插件介绍

1. 基于 Lean ssrp 全新MOD的 Hello World ,在原插件的基础上做了一些优化用户操作体验的修改，感谢插件原作者所做出的的努力和贡献！ 
1. 节点列表支持国旗显示并且页面打开自动检测节点的连接时间。  
1. 支持各种分流组合，并且可以自己编辑所有分流的域名，相当于七组自定义分流。  
1. 将节点订阅转移至[高级设置]请悉知。  
1. 底部状态栏：左边显示国旗地区以及IP,右边为四个站点的可访问状态，彩色为可访问，灰色为不能访问。 
1. 优化了国旗匹配方法。  
1. 建议搭配Argon主题，以达到最佳的显示效果。  

欢迎提交bug。

### 如何编译
假设你的Lean openwrt（最新版本19.07） 在 lede 目录下
```
cd lede/package/lean/  

git clone https://github.com/jerrykuku/lua-maxminddb.git  #git lua-maxminddb 依赖

git clone https://github.com/jerrykuku/luci-app-vssr.git  

make menuconfig

make -j1 V=s
```

### 问题解决

使用lede最新源码编译失败，报错缺少依赖：

```
satisfy_dependencies_for: Cannot satisfy the following dependencies for luci-app-vssr:
- shadowsocksr-libev-ssr-local
- shadowsocksr-libev-ssr-redir
- shadowsocksr-libev-ssr-check
- xray-core
- xray-plugin
- shadowsocksr-libev-ssr-server
opkg_install_cmd: Cannot install package luci-app-vssr.
```

原因是lede缺少软件源，解决办法，清除缓存重新下载编译：

```
# 1.清除缓存
rm -rf tmp

# 2.feeds.conf文件添加源
src-git helloworld https://github.com/fw876/helloworld
src-git passwall https://github.com/xiaorouji/openwrt-passwall

# 3.重新执行升级安装下载编译等操作
./scripts/feeds update -a
./scripts/feeds install -a
make -j8 download V=s
make -j1 V=s
```

或者也可以完全删除lede，重新git并修改feeds.conf（比较耗时）

### 感谢

https://github.com/coolsnowwolf/lede

### 我的其它项目
Argon theme ：https://github.com/jerrykuku/luci-theme-argon  
京东签到插件 ：https://github.com/jerrykuku/luci-app-jd-dailybonus  
openwrt-nanopi-r1s-h5 ： https://github.com/jerrykuku/openwrt-nanopi-r1s-h5