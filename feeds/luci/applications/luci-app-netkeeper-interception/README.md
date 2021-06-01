# feed-netkeeper

## 本软件源包含四个软件
```
netkeeper（闪讯插件）
luci-proto-netkeeper（闪讯拨号界面）
netkeeper-interception（闪讯拦截服务）
luci-app-netkeeper-interception（闪讯拦截服务界面）
```

### [master分支](https://github.com/CCnut/feed-netkeeper/tree/master) 支持Javascript版本的LUCI，以及使用procd_add_reload_trigger作为页面触发器
### [LUCI-JS-UCITRACK分支](https://github.com/CCnut/feed-netkeeper/tree/LUCI-JS-UCITRACK) 支持Javascript版本的LUCI，以及使用UCITRACK作为页面触发器
### [LUCI-LUA-UCITRACK分支](https://github.com/CCnut/feed-netkeeper/tree/LUCI-JS-UCITRACK) 支持Lua版本的LUCI，以及使用UCITRACK作为页面触发器
_2020.09.19 OpenWrt master分支 测试通过_

## 常见问题

如果master和LUCI-JS-UCITRACK分支遇到语言显示问题，请将软件内的```zh_Hans```重命名为```zh-cn```

如果master分支遇到启用按钮无反应问题，请使用[LUCI-JS-UCITRACK分支](https://github.com/CCnut/feed-netkeeper/tree/LUCI-JS-UCITRACK)

如果遇到接口界面看不到闪讯拨号协议问题，请使用[LUCI-LUA-UCITRACK分支](https://github.com/CCnut/feed-netkeeper/tree/LUCI-JS-UCITRACK)

选择```luci-app-netkeeper-interception```即可全部编译

请自行编译安装后使用

# 使用方法

## 普通插件

在 _网络 -> 接口 -> 编辑WAN -> 选择闪讯拨号 -> 确认切换_ 后

然后输入 _用户名_ 和 _密码_ 选择对应的 _闪讯插件_ 保存应用即可拨号

## 拦截插件

在 _网络 -> 接口 -> 编辑WAN -> 选择闪讯拨号 -> 确认切换_ 后

选择 _闪讯拦截_ 插件并开启闪讯拦截服务后，在PC端使用闪讯客户端拨号，会自动获取用户名与密码并拨号

**可以不用填写 _用户名_ 和 _密码_**

### 特别鸣谢
netkeeper的核心源码来自于miao1007的[Openwrt-NetKeeper](https://github.com/miao1007/Openwrt-NetKeeper)
