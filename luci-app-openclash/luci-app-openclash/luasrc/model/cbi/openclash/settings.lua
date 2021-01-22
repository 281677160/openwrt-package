
local NXFS = require "nixio.fs"
local SYS  = require "luci.sys"
local HTTP = require "luci.http"
local DISP = require "luci.dispatcher"
local UTIL = require "luci.util"
local fs = require "luci.openclash"
local uci = require "luci.model.uci".cursor()

font_green = [[<font color="green">]]
font_red = [[<font color="red">]]
font_off = [[</font>]]
bold_on  = [[<strong>]]
bold_off = [[</strong>]]

local op_mode = string.sub(luci.sys.exec('uci get openclash.config.operation_mode 2>/dev/null'),0,-2)
if not op_mode then op_mode = "redir-host" end

m = Map("openclash", translate("Global Settings(Will Modify The Config File Or Subscribe According To The Settings On This Page)"))
m.pageaction = false
s = m:section(TypedSection, "openclash")
s.anonymous = true

s:tab("op_mode", translate("Operation Mode"))
s:tab("settings", translate("General Settings"))
s:tab("dns", translate("DNS Setting"))
s:tab("lan_ac", translate("Access Control"))
if op_mode == "fake-ip" then
s:tab("rules", translate("Rules Setting(Access Control)"))
else
s:tab("rules", translate("Rules Setting"))
end
s:tab("dashboard", translate("Dashboard Settings"))
s:tab("rules_update", translate("Rules Update"))
s:tab("geo_update", translate("GEOIP Update"))
s:tab("chnr_update", translate("Chnroute Update"))
s:tab("auto_restart", translate("Auto Restart"))
s:tab("version_update", translate("Version Update"))
s:tab("debug", translate("Debug Logs"))

o = s:taboption("op_mode", ListValue, "en_mode", font_red..bold_on..translate("Select Mode")..bold_off..font_off)
o.description = translate("Select Mode For OpenClash Work, Try Flush DNS Cache If Network Error")
if op_mode == "redir-host" then
o:value("redir-host", translate("redir-host"))
o:value("redir-host-tun", translate("redir-host(tun mode)"))
o:value("redir-host-vpn", translate("redir-host-vpn(game mode)"))
o:value("redir-host-mix", translate("redir-host-mix(tun mix mode)"))
o.default = "redir-host"
else
o:value("fake-ip", translate("fake-ip"))
o:value("fake-ip-tun", translate("fake-ip(tun mode)"))
o:value("fake-ip-vpn", translate("fake-ip-vpn(game mode)"))
o:value("fake-ip-mix", translate("fake-ip-mix(tun mix mode)"))
o.default = "fake-ip"
end

o = s:taboption("op_mode", Flag, "enable_udp_proxy", font_red..bold_on..translate("Proxy UDP Traffics")..bold_off..font_off)
o.description = translate("Select Mode For UDP Traffics, The Servers Must Support UDP while Choose Proxy")
o:depends("en_mode", "redir-host")
o:depends("en_mode", "fake-ip")
o.default=1

o = s:taboption("op_mode", ListValue, "stack_type", translate("Select Stack Type"))
o.description = translate("Select Stack Type For Tun Mode, According To The Running Speed on Your Machine")
o:depends("en_mode", "redir-host-tun")
o:depends("en_mode", "fake-ip-tun")
o:depends("en_mode", "redir-host-mix")
o:depends("en_mode", "fake-ip-mix")
o:value("system", translate("System　"))
o:value("gvisor", translate("Gvisor"))
o.default = "system"

o = s:taboption("op_mode", ListValue, "proxy_mode", font_red..bold_on..translate("Proxy Mode")..bold_off..font_off)
o.description = translate("Select Proxy Mode, Use Script Mode Could Prevent Proxy BT traffics If Rules Support, eg.lhie1's")
o:value("rule", translate("Rule Proxy Mode"))
o:value("global", translate("Global Proxy Mode"))
o:value("direct", translate("Direct Proxy Mode"))
o:value("script", translate("Script Proxy Mode (Tun Core Only)"))
o.default = "rule"

o = s:taboption("op_mode", Flag, "enable_rule_proxy", font_red..bold_on..translate("Rule Match Proxy Mode")..bold_off..font_off)
o.description = translate("Only Proxy Rules Match, Prevent BT/P2P Passing")
o.default=0

o = s:taboption("op_mode", Flag, "common_ports", font_red..bold_on..translate("Common Ports Proxy Mode")..bold_off..font_off)
o.description = translate("Only Common Ports, Prevent BT/P2P Passing")
o.default=0
o:depends("en_mode", "redir-host")
o:depends("en_mode", "redir-host-tun")
o:depends("en_mode", "redir-host-vpn")
o:depends("en_mode", "redir-host-mix")

o = s:taboption("op_mode", Flag, "china_ip_route", translate("China IP Route"))
o.description = translate("Bypass The China Network Flows, Improve Performance")
o.default=0
o:depends("en_mode", "redir-host")
o:depends("en_mode", "redir-host-tun")
o:depends("en_mode", "redir-host-vpn")
o:depends("en_mode", "redir-host-mix")

o = s:taboption("op_mode", Flag, "small_flash_memory", translate("Small Flash Memory"))
o.description = translate("Move Core And GEOIP Data File To /tmp/etc/openclash For Small Flash Memory Device")
o.default=0

---- Operation Mode
switch_mode = s:taboption("op_mode", DummyValue, "", nil)
switch_mode.template = "openclash/switch_mode"

---- General Settings
local cpu_model=SYS.exec("opkg status libc 2>/dev/null |grep 'Architecture' |awk -F ': ' '{print $2}' 2>/dev/null")
o = s:taboption("settings", ListValue, "core_version", font_red..bold_on..translate("Chose to Download")..bold_off..font_off)
o.description = translate("CPU Model")..': '..font_green..bold_on..cpu_model..bold_off..font_off..', '..translate("Select Based On Your CPU Model For Core Update, Wrong Version Will Not Work")
o:value("linux-386")
o:value("linux-amd64", translate("linux-amd64(x86-64)"))
o:value("linux-armv5")
o:value("linux-armv6")
o:value("linux-armv7")
o:value("linux-armv8")
o:value("linux-mips-hardfloat")
o:value("linux-mips-softfloat")
o:value("linux-mips64")
o:value("linux-mips64le")
o:value("linux-mipsle-softfloat")
o:value("linux-mipsle-hardfloat")
o:value("0", translate("Not Set"))
o.default=0

o = s:taboption("settings", ListValue, "interface_name", font_red..bold_on..translate("Bind Network Interface")..bold_off..font_off)
local de_int = SYS.exec("ip route |grep 'default' |awk '{print $5}' 2>/dev/null")
o.description = translate("Default Interface Name:").." "..font_green..bold_on..de_int..bold_off..font_off..translate(",Try Enable If Network Loopback")
local interfaces = SYS.exec("ls -l /sys/class/net/ 2>/dev/null |awk '{print $9}' 2>/dev/null")
for interface in string.gmatch(interfaces, "%S+") do
   o:value(interface)
end
o:value("0", translate("Disable"))
o.default=0

o = s:taboption("settings", ListValue, "log_level", translate("Log Level"))
o.description = translate("Select Core's Log Level")
o:value("info", translate("Info Mode"))
o:value("warning", translate("Warning Mode"))
o:value("error", translate("Error Mode"))
o:value("debug", translate("Debug Mode"))
o:value("silent", translate("Silent Mode"))
o.default = "silent"

o = s:taboption("settings", Flag, "intranet_allowed", translate("Only intranet allowed"))
o.description = translate("When Enabled, The Control Panel And The Connection Broker Port Will Not Be Accessible From The Public Network")
o.default=0

o = s:taboption("settings", Value, "proxy_port")
o.title = translate("Redir Port")
o.default = 7892
o.datatype = "port"
o.rmempty = false
o.description = translate("Please Make Sure Ports Available")

o = s:taboption("settings", Value, "http_port")
o.title = translate("HTTP(S) Port")
o.default = 7890
o.datatype = "port"
o.rmempty = false
o.description = translate("Please Make Sure Ports Available")

o = s:taboption("settings", Value, "socks_port")
o.title = translate("SOCKS5 Port")
o.default = 7891
o.datatype = "port"
o.rmempty = false
o.description = translate("Please Make Sure Ports Available")

o = s:taboption("settings", Value, "mixed_port")
o.title = translate("Mixed Port")
o.default = 7893
o.datatype = "port"
o.rmempty = false
o.description = translate("Please Make Sure Ports Available")

---- DNS Settings
o = s:taboption("dns", Flag, "enable_redirect_dns", font_red..bold_on..translate("Redirect Local DNS Setting")..bold_off..font_off)
o.description = translate("Set Local DNS Redirect")
o.default=1

o = s:taboption("dns", Flag, "enable_custom_dns", font_red..bold_on..translate("Custom DNS Setting")..bold_off..font_off)
o.description = font_red..bold_on..translate("Set OpenClash Upstream DNS Resolve Server")..bold_off..font_off
o.default=0

o = s:taboption("dns", Flag, "ipv6_enable", translate("Enable ipv6 Resolve"))
o.description = font_red..bold_on..translate("Enable Clash to Resolve ipv6 DNS Requests")..bold_off..font_off
o.default=0

o = s:taboption("dns", Flag, "disable_masq_cache", translate("Disable Dnsmasq's DNS Cache"))
o.description = translate("Recommended Enabled For Avoiding Some Connection Errors")..font_red..bold_on..translate("(Maybe Incompatible For Your Firmware)")..bold_off..font_off
o.default=0

o = s:taboption("dns", Flag, "dns_advanced_setting", translate("Advanced Setting"))
o.description = translate("DNS Advanced Settings")..font_red..bold_on..translate("(Please Don't Modify it at Will)")..bold_off..font_off
o.default=0

if op_mode == "fake-ip" then
o = s:taboption("dns", Button, translate("Fake-IP-Filter List Update")) 
o.title = translate("Fake-IP-Filter List Update")
o:depends("dns_advanced_setting", "1")
o.inputtitle = translate("Check And Update")
o.inputstyle = "reload"
o.write = function()
  m.uci:set("openclash", "config", "enable", 1)
  m.uci:commit("openclash")
  SYS.call("rm -rf /tmp/openclash_fake_filter.list >/dev/null 2>&1 && /etc/init.d/openclash restart >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

custom_fake_black = s:taboption("dns", Value, "custom_fake_filter")
custom_fake_black.template = "cbi/tvalue"
custom_fake_black.description = translate("Domain Names In The List Do Not Return Fake-IP, One rule per line")
custom_fake_black.rows = 20
custom_fake_black.wrap = "off"
custom_fake_black:depends("dns_advanced_setting", "1")

function custom_fake_black.cfgvalue(self, section)
	return NXFS.readfile("/etc/openclash/custom/openclash_custom_fake_filter.list") or ""
end
function custom_fake_black.write(self, section, value)

	if value then
		value = value:gsub("\r\n?", "\n")
		local old_value = NXFS.readfile("/etc/openclash/custom/openclash_custom_fake_filter.list")
	  if value ~= old_value then
			NXFS.writefile("/etc/openclash/custom/openclash_custom_fake_filter.list", value)
		end
	end
end
end

o = s:taboption("dns", Value, "custom_domain_dns_server", translate("Specify DNS Server"))
o.description = translate("Specify DNS Server For List and Server Nodes With Fake-IP Mode, Only One IP Server Address Support")
o.default="114.114.114.114"
o.placeholder = translate("114.114.114.114 or 127.0.0.1#5300")
o:depends("dns_advanced_setting", "1")

custom_domain_dns = s:taboption("dns", Value, "custom_domain_dns")
custom_domain_dns.template = "cbi/tvalue"
custom_domain_dns.description = translate("Domain Names In The List Use The Custom DNS Server, One rule per line")
custom_domain_dns.rows = 20
custom_domain_dns.wrap = "off"
custom_domain_dns:depends("dns_advanced_setting", "1")

function custom_domain_dns.cfgvalue(self, section)
	return NXFS.readfile("/etc/openclash/custom/openclash_custom_domain_dns.list") or ""
end
function custom_domain_dns.write(self, section, value)

	if value then
		value = value:gsub("\r\n?", "\n")
		local old_value = NXFS.readfile("/etc/openclash/custom/openclash_custom_domain_dns.list")
	  if value ~= old_value then
			NXFS.writefile("/etc/openclash/custom/openclash_custom_domain_dns.list", value)
		end
	end
end

---- Access Control
if op_mode == "redir-host" then
o = s:taboption("lan_ac", ListValue, "lan_ac_mode", translate("LAN Access Control Mode"))
o:value("0", translate("Black List Mode"))
o:value("1", translate("White List Mode"))
o.default=0

ip_b = s:taboption("lan_ac", DynamicList, "lan_ac_black_ips", translate("LAN Bypassed Host List"))
ip_b:depends("lan_ac_mode", "0")
ip_b.datatype = "ipaddr"

mac_b = s:taboption("lan_ac", DynamicList, "lan_ac_black_macs", translate("LAN Bypassed Mac List"))
mac_b.datatype = "list(macaddr)"
mac_b.rmempty  = true
mac_b:depends("lan_ac_mode", "0")

ip_w = s:taboption("lan_ac", DynamicList, "lan_ac_white_ips", translate("LAN Proxied Host List"))
ip_w:depends("lan_ac_mode", "1")
ip_w.datatype = "ipaddr"

mac_w = s:taboption("lan_ac", DynamicList, "lan_ac_white_macs", translate("LAN Proxied Mac List"))
mac_w.datatype = "list(macaddr)"
mac_w.rmempty  = true
mac_w:depends("lan_ac_mode", "1")

luci.ip.neighbors({ family = 4 }, function(n)
	if n.mac and n.dest then
		ip_b:value(n.dest:string())
		ip_w:value(n.dest:string())
		mac_b:value(n.mac, "%s (%s)" %{ n.mac, n.dest:string() })
		mac_w:value(n.mac, "%s (%s)" %{ n.mac, n.dest:string() })
	end
end)
end

o = s:taboption("lan_ac", DynamicList, "wan_ac_black_ips", translate("WAN Bypassed Host List"))
o.datatype = "ipaddr"
o.description = translate("In The Fake-IP Mode, Only Pure IP Requests Are Supported")

---- Rules Settings
o = s:taboption("rules", Flag, "rule_source", translate("Enable Other Rules"))
o.description = translate("Use Other Rules")
o.default=0

if op_mode == "fake-ip" then
o = s:taboption("rules", Flag, "enable_custom_clash_rules", font_red..bold_on..translate("Custom Clash Rules(Access Control)")..bold_off..font_off)
else
o = s:taboption("rules", Flag, "enable_custom_clash_rules", font_red..bold_on..translate("Custom Clash Rules")..bold_off..font_off)
end
o.description = translate("Use Custom Rules")
o.default=0

custom_rules = s:taboption("rules", Value, "custom_rules")
custom_rules:depends("enable_custom_clash_rules", 1)
custom_rules.template = "cbi/tvalue"
custom_rules.description = translate("Custom Rules Here, For More Go Github:https://github.com/Dreamacro/clash/blob/master/README.md, IP To CIDR: http://ip2cidr.com")
custom_rules.rows = 20
custom_rules.wrap = "off"

function custom_rules.cfgvalue(self, section)
	return NXFS.readfile("/etc/openclash/custom/openclash_custom_rules.list") or ""
end
function custom_rules.write(self, section, value)
	if value then
		value = value:gsub("\r\n?", "\n")
		local old_value = NXFS.readfile("/etc/openclash/custom/openclash_custom_rules.list")
	  if value ~= old_value then
			NXFS.writefile("/etc/openclash/custom/openclash_custom_rules.list", value)
		end
	end
end

custom_rules_2 = s:taboption("rules", Value, "custom_rules_2")
custom_rules_2:depends("enable_custom_clash_rules", 1)
custom_rules_2.template = "cbi/tvalue"
custom_rules_2.description = translate("Custom Rules 2 Here, For More Go Github:https://github.com/Dreamacro/clash/blob/master/README.md, IP To CIDR: http://ip2cidr.com")
custom_rules_2.rows = 20
custom_rules_2.wrap = "off"

function custom_rules_2.cfgvalue(self, section)
	return NXFS.readfile("/etc/openclash/custom/openclash_custom_rules_2.list") or ""
end
function custom_rules_2.write(self, section, value)
	if value then
		value = value:gsub("\r\n?", "\n")
		local old_value = NXFS.readfile("/etc/openclash/custom/openclash_custom_rules_2.list")
	  if value ~= old_value then
			NXFS.writefile("/etc/openclash/custom/openclash_custom_rules_2.list", value)
		end
	end
end

---- update Settings
o = s:taboption("rules_update", Flag, "other_rule_auto_update", translate("Auto Update"))
o.description = font_red..bold_on..translate("Auto Update Other Rules")..bold_off..font_off
o.default=0

o = s:taboption("rules_update", ListValue, "other_rule_update_week_time", translate("Update Time (Every Week)"))
o:value("*", translate("Every Day"))
o:value("1", translate("Every Monday"))
o:value("2", translate("Every Tuesday"))
o:value("3", translate("Every Wednesday"))
o:value("4", translate("Every Thursday"))
o:value("5", translate("Every Friday"))
o:value("6", translate("Every Saturday"))
o:value("0", translate("Every Sunday"))
o.default=1

o = s:taboption("rules_update", ListValue, "other_rule_update_day_time", translate("Update time (every day)"))
for t = 0,23 do
o:value(t, t..":00")
end
o.default=0

o = s:taboption("rules_update", Button, translate("Other Rules Update")) 
o.title = translate("Update Other Rules")
o.inputtitle = translate("Check And Update")
o.description = translate("Other Rules Update(Only in Use)")
o.inputstyle = "reload"
o.write = function()
  m.uci:set("openclash", "config", "enable", 1)
  m.uci:commit("openclash")
  SYS.call("/usr/share/openclash/openclash_rule.sh >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

o = s:taboption("geo_update", Flag, "geo_auto_update", translate("Auto Update"))
o.description = translate("Auto Update GEOIP Database")
o.default=0

o = s:taboption("geo_update", ListValue, "geo_update_week_time", translate("Update Time (Every Week)"))
o:value("*", translate("Every Day"))
o:value("1", translate("Every Monday"))
o:value("2", translate("Every Tuesday"))
o:value("3", translate("Every Wednesday"))
o:value("4", translate("Every Thursday"))
o:value("5", translate("Every Friday"))
o:value("6", translate("Every Saturday"))
o:value("0", translate("Every Sunday"))
o.default=1

o = s:taboption("geo_update", ListValue, "geo_update_day_time", translate("Update time (every day)"))
for t = 0,23 do
o:value(t, t..":00")
end
o.default=0

o = s:taboption("geo_update", Value, "geo_custom_url")
o.title = translate("Custom GEOIP URL")
o.rmempty = false
o.description = translate("Custom GEOIP Data URL, Click Button Below To Refresh After Edit")
o:value("http://www.ideame.top/mmdb/Country.mmdb", translate("Alecthw-Version")..translate("(Default)"))
o:value("https://cdn.jsdelivr.net/gh/Hackl0us/GeoIP2-CN@release/Country.mmdb", translate("Hackl0us-Version")..translate("(Only CN)"))
o:value("https://static.clash.to/GeoIP2/GeoIP2-Country.mmdb", translate("Static.clash.to"))
o:value("https://geolite.clash.dev/Country.mmdb", translate("Geolite.clash.dev"))
o.default = "http://www.ideame.top/mmdb/Country.mmdb"

o = s:taboption("geo_update", Button, translate("GEOIP Update")) 
o.title = translate("Update GEOIP Database")
o.inputtitle = translate("Check And Update")
o.inputstyle = "reload"
o.write = function()
  m.uci:set("openclash", "config", "enable", 1)
  m.uci:commit("openclash")
  SYS.call("/usr/share/openclash/openclash_ipdb.sh >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end

if op_mode == "redir-host" then
o = s:taboption("chnr_update", Flag, "chnr_auto_update", translate("Auto Update"))
o.description = translate("Auto Update Chnroute Lists")
o.default=0

o = s:taboption("chnr_update", ListValue, "chnr_update_week_time", translate("Update Time (Every Week)"))
o:value("*", translate("Every Day"))
o:value("1", translate("Every Monday"))
o:value("2", translate("Every Tuesday"))
o:value("3", translate("Every Wednesday"))
o:value("4", translate("Every Thursday"))
o:value("5", translate("Every Friday"))
o:value("6", translate("Every Saturday"))
o:value("0", translate("Every Sunday"))
o.default=1

o = s:taboption("chnr_update", ListValue, "chnr_update_day_time", translate("Update time (every day)"))
for t = 0,23 do
o:value(t, t..":00")
end
o.default=0

o = s:taboption("chnr_update", Value, "chnr_custom_url")
o.title = translate("Custom Chnroute Lists URL")
o.rmempty = false
o.description = translate("Custom Chnroute Lists URL, Click Button Below To Refresh After Edit")
o:value("https://ispip.clang.cn/all_cn.txt", translate("Clang-CN")..translate("(Default)"))
o:value("https://ispip.clang.cn/all_cn_cidr.txt", translate("Clang-CN-CIDR"))
o:value("https://cdn.jsdelivr.net/gh/Hackl0us/GeoIP2-CN@release/CN-ip-cidr.txt", translate("Hackl0us-CN-CIDR")..translate("(Large Size)"))
o.default = "https://ispip.clang.cn/all_cn.txt"

o = s:taboption("chnr_update", Button, translate("Chnroute Lists Update")) 
o.title = translate("Update Chnroute Lists")
o.inputtitle = translate("Check And Update")
o.inputstyle = "reload"
o.write = function()
  m.uci:set("openclash", "config", "enable", 1)
  m.uci:commit("openclash")
  SYS.call("/usr/share/openclash/openclash_chnroute.sh >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end
end

o = s:taboption("auto_restart", Flag, "auto_restart", translate("Auto Restart"))
o.description = translate("Auto Restart OpenClash")
o.default=0

o = s:taboption("auto_restart", ListValue, "auto_restart_week_time", translate("Restart Time (Every Week)"))
o:value("*", translate("Every Day"))
o:value("1", translate("Every Monday"))
o:value("2", translate("Every Tuesday"))
o:value("3", translate("Every Wednesday"))
o:value("4", translate("Every Thursday"))
o:value("5", translate("Every Friday"))
o:value("6", translate("Every Saturday"))
o:value("0", translate("Every Sunday"))
o.default=1

o = s:taboption("auto_restart", ListValue, "auto_restart_day_time", translate("Restart time (every day)"))
for t = 0,23 do
o:value(t, t..":00")
end
o.default=0

---- Dashboard Settings
local lan_ip=SYS.exec("uci get network.lan.ipaddr 2>/dev/null |awk -F '/' '{print $1}' 2>/dev/null |tr -d '\n'")
local cn_port=SYS.exec("uci get openclash.config.cn_port 2>/dev/null |tr -d '\n'")
o = s:taboption("dashboard", Value, "cn_port")
o.title = translate("Dashboard Port")
o.default = 9090
o.datatype = "port"
o.rmempty = false
o.description = translate("Dashboard Address Example:").." "..font_green..bold_on..lan_ip.."/luci-static/openclash、"..lan_ip..':'..cn_port..'/ui'..bold_off..font_off

o = s:taboption("dashboard", Value, "dashboard_password")
o.title = translate("Dashboard Secret")
o.rmempty = true
o.description = translate("Set Dashboard Secret")

---- version update
core_update = s:taboption("version_update", DummyValue, "", nil)
core_update.template = "openclash/update"

---- debug
debug_log = s:taboption("debug", Value, "debug_log")
debug_log.template = "cbi/tvalue"
debug_log.readonly=true
debug_log.rows = 30
debug_log.wrap = "off"
function debug_log.cfgvalue(self, section)
  return NXFS.readfile("/tmp/openclash_debug.log") or ""
end
  
o = s:taboption("debug", Button, translate("Generate Logs")) 
o.title = translate("Generate Logs")
o.inputtitle = translate("Click to Generate")
o.inputstyle = "reload"
o.write = function()
  SYS.call("/usr/share/openclash/openclash_debug.sh")
end

-- [[ Edit Server ]] --
s = m:section(TypedSection, "dns_servers", translate("Add Custom DNS Servers")..translate("(Take Effect After Choose Above)"))
s.anonymous = true
s.addremove = true
s.sortable = false
s.template = "cbi/tblsection"
s.rmempty = false

---- enable flag
o = s:option(Flag, "enabled", translate("Enable"), font_red..bold_on..translate("(Enable or Disable)")..bold_off..font_off)
o.rmempty     = false
o.default     = o.enabled
o.cfgvalue    = function(...)
    return Flag.cfgvalue(...) or "1"
end

---- group
o = s:option(ListValue, "group", translate("DNS Server Group"))
o.description = font_red..bold_on..translate("(NameServer Group Must Be Set)")..bold_off..font_off
o:value("nameserver", translate("NameServer"))
o:value("fallback", translate("FallBack"))
o.default     = "nameserver"
o.rempty      = false

---- IP address
o = s:option(Value, "ip", translate("DNS Server Address"))
o.description = font_red..bold_on..translate("(Do Not Add Type Ahead)")..bold_off..font_off
o.placeholder = translate("Not Null")
o.datatype = "or(host, string)"
o.rmempty = true

---- port
o = s:option(Value, "port", translate("DNS Server Port"))
o.description = font_red..bold_on..translate("(Require When Use Non-Standard Port)")..bold_off..font_off
o.datatype    = "port"
o.rempty      = true

---- type
o = s:option(ListValue, "type", translate("DNS Server Type"))
o.description = font_red..bold_on..translate("(Communication protocol)")..bold_off..font_off
o:value("udp", translate("UDP"))
o:value("tcp", translate("TCP"))
o:value("tls", translate("TLS"))
o:value("https", translate("HTTPS"))
o.default     = "udp"
o.rempty      = false

-- [[ Other Rules Manage ]]--
ss = m:section(TypedSection, "other_rules", translate("Other Rules Edit")..translate("(Take Effect After Choose Above)"))
ss.anonymous = true
ss.addremove = true
ss.sortable = true
ss.template = "cbi/tblsection"
ss.extedit = luci.dispatcher.build_url("admin/services/openclash/other-rules-edit/%s")
function ss.create(...)
	local sid = TypedSection.create(...)
	if sid then
		luci.http.redirect(ss.extedit % sid)
		return
	end
end

o = ss:option(Flag, "enabled", translate("Enable"))
o.rmempty     = false
o.default     = o.enabled
o.cfgvalue    = function(...)
    return Flag.cfgvalue(...) or "1"
end

o = ss:option(DummyValue, "config", translate("Config File"))
function o.cfgvalue(...)
	return Value.cfgvalue(...) or translate("None")
end

o = ss:option(DummyValue, "rule_name", translate("Other Rules Name"))
function o.cfgvalue(...)
	if Value.cfgvalue(...) == "lhie1" then
		return translate("lhie1 Rules")
	elseif Value.cfgvalue(...) == "ConnersHua" then
		return translate("ConnersHua(Provider-type) Rules")
	elseif Value.cfgvalue(...) == "ConnersHua_return" then
		return translate("ConnersHua Return Rules")
	else
		return translate("None")
	end
end

o = ss:option(DummyValue, "Note", translate("Note"))
function o.cfgvalue(...)
	return Value.cfgvalue(...) or translate("None")
end

-- [[ Edit Authentication ]] --
s = m:section(TypedSection, "authentication", translate("Set Authentication of SOCKS5/HTTP(S)"))
s.anonymous = true
s.addremove = true
s.sortable = false
s.template = "cbi/tblsection"
s.rmempty = false

---- enable flag
o = s:option(Flag, "enabled", translate("Enable"))
o.rmempty     = false
o.default     = o.enabled
o.cfgvalue    = function(...)
    return Flag.cfgvalue(...) or "1"
end

---- username
o = s:option(Value, "username", translate("Username"))
o.placeholder = translate("Not Null")
o.rempty      = true

---- password
o = s:option(Value, "password", translate("Password"))
o.placeholder = translate("Not Null")
o.rmempty = true

if op_mode == "redir-host" then
s = m:section(TypedSection, "openclash", translate("Set Custom Hosts, Only Work with Redir-Host Mode"))
s.anonymous = true

custom_hosts = s:option(Value, "custom_hosts")
custom_hosts.template = "cbi/tvalue"
custom_hosts.description = translate("Custom Hosts Here, For More Go Github:https://github.com/Dreamacro/clash/blob/master/README.md")
custom_hosts.rows = 20
custom_hosts.wrap = "off"

function custom_hosts.cfgvalue(self, section)
	return NXFS.readfile("/etc/openclash/custom/openclash_custom_hosts.list") or ""
end
function custom_hosts.write(self, section, value)
	if value then
		value = value:gsub("\r\n?", "\n")
		local old_value = NXFS.readfile("/etc/openclash/custom/openclash_custom_hosts.list")
	  if value ~= old_value then
			NXFS.writefile("/etc/openclash/custom/openclash_custom_hosts.list", value)
		end
	end
end
end

local t = {
    {Commit, Apply}
}

a = m:section(Table, t)

o = a:option(Button, "Commit") 
o.inputtitle = translate("Commit Configurations")
o.inputstyle = "apply"
o.write = function()
  m.uci:commit("openclash")
end

o = a:option(Button, "Apply")
o.inputtitle = translate("Apply Configurations")
o.inputstyle = "apply"
o.write = function()
  m.uci:set("openclash", "config", "enable", 1)
  m.uci:commit("openclash")
  SYS.call("/etc/init.d/openclash restart >/dev/null 2>&1 &")
  HTTP.redirect(DISP.build_url("admin", "services", "openclash"))
end
return m


