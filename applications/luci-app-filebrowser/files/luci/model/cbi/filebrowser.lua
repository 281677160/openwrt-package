require("luci.sys")
require("luci.util")
require("luci.model.ipkg")
local fs  = require "nixio.fs"

local uci = require "luci.model.uci".cursor()

local m, s

local running=(luci.sys.call("pidof filebrowser > /dev/null") == 0)

local button = ""
local state_msg = ""
local trport = uci:get("filebrowser", "config", "port")
if running  then
	button = "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<input type=\"button\" value=\" " .. translate("打开管理界面") .. " \" onclick=\"window.open('http://'+window.location.hostname+':" .. trport .. "')\"/>"
end

if running then
        state_msg = "<b><font color=\"green\">" .. translate("FileBrowser运行中") .. "</font></b>"
else
        state_msg = "<b><font color=\"red\">" .. translate("FileBrowser未运行") .. "</font></b>"
end

m = Map("filebrowser", translate("文件管理器"), translate("FileBrowser是一个基于Go的在线文件管理器，助您方便的管理设备上的文件，主程序来自荒野无灯魔改版，数据库文件建议放到用Docker命令后的opt目录或者放在升级不会被覆盖的目录当中否则升级会覆盖本软件数据库文件!保存应用后重启openwrt才会启动!数据库创建后再通过此界面修改密码无效，修改密码可以在filebrowser界面的管理用户里面修改密码，若忘记密码可以连接ssh删除数据库文件再重新启动openwrt即可重新自动创建数据库文件") .. button
        .. "<br/><br/>" .. translate("FileBrowser运行状态").. " : "  .. state_msg .. "<br/>")
        
s = m:section(TypedSection, "filebrowser", "")
s.addremove = false
s.anonymous = true

enable = s:option(Flag, "enabled", translate("启用"))
enable.rmempty = false

o = s:option(ListValue, "addr_type", translate("监听地址"))
o:value("local", translate("监听本机地址"))
o:value("lan", translate("监听局域网地址"))
o:value("wan", translate("监听全部地址"))
o.default = "lan"
o.rmempty = false

o = s:option(Value, "port", translate("监听端口"))
o.placeholder = 8082
o.default     = 8082
o.datatype    = "port"
o.rmempty     = false

o = s:option(Value, "root_dir", translate("开放目录"))
o.placeholder = "/"
o.default     = "/"
o.rmempty     = false

o = s:option(Value, "username", translate("管理员用户名"))
o.placeholder = "admin"
o.default     = "admin"
o.rmempty     = false

o = s:option(Value, "password", translate("管理员密码"))
o.password    = true
o.placeholder = "admin"
o.default     = "admin"
o.rmempty     = false

o = s:option(Value, "db_dir", translate("数据库目录"))
o.placeholder = "/opt"
o.default     = "/opt"
o.rmempty     = false
o.description = translate("普通用户请勿随意更改")

o = s:option(Value, "db_name", translate("数据库名"))
o.placeholder = "filebrowser.db"
o.default     = "filebrowser.db"
o.rmempty     = false
o.description = translate("普通用户请勿随意更改")

return m
