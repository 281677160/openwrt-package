-- Copyright (C) 2017 yushi studio <ywb94@qq.com> github.com/ywb94
-- Copyright (C) 2018 lean <coolsnowwolf@gmail.com> github.com/coolsnowwolf
-- Licensed to the public under the GNU General Public License v3.

local m, s, sec, o, kcp_enable
local vssr = "vssr"
local gfw_count=0
local ad_count=0
local ip_count=0
local gfwmode=0

if nixio.fs.access("/etc/dnsmasq.vssr/gfw_list.conf") then
gfwmode=1		
end

local uci = luci.model.uci.cursor()

local sys = require "luci.sys"

if gfwmode==1 then 
 gfw_count = tonumber(sys.exec("cat /etc/dnsmasq.vssr/gfw_list.conf | wc -l"))/2
 if nixio.fs.access("/etc/dnsmasq.vssr/ad.conf") then
  ad_count=tonumber(sys.exec("cat /etc/dnsmasq.vssr/ad.conf | wc -l"))
 end
end
 
if nixio.fs.access("/etc/china_ssr.txt") then 
 ip_count = sys.exec("cat /etc/china_ssr.txt | wc -l")
end

m = Map(vssr)

m:section(SimpleSection).template  = "vssr/status"

local server_table = {}
local v2ray_table = {}
uci:foreach(vssr, "servers", function(s)
	if s.alias then
		server_table[s[".name"]] = "[%s]:%s" %{string.upper(s.type), s.alias}
	elseif s.server and s.server_port then
		server_table[s[".name"]] = "[%s]:%s:%s" %{string.upper(s.type), s.server, s.server_port}
	end
if s.type == "v2ray"	then
		if s.alias then
			v2ray_table[s[".name"]] = "[%s]:%s" %{string.upper(s.type), s.alias}
		elseif s.server and s.server_port then
			v2ray_table[s[".name"]] = "[%s]:%s:%s" %{string.upper(s.type), s.server, s.server_port}
		end
	end
end)

local key_table = {}   
for key,_ in pairs(server_table) do  
    table.insert(key_table,key)  
end 

table.sort(key_table)  

local key_table_v2 = {}  
for key,_ in pairs(v2ray_table) do  
    table.insert(key_table_v2,key)  
end 

table.sort(key_table_v2)

-- [[ Global Setting ]]--
s = m:section(TypedSection, "global", translate("Basic Settings"))
s.anonymous = true



o = s:option(ListValue, "global_server", translate("Main Server"))
o:value("nil", translate("Disable"))
if nixio.fs.access("/usr/sbin/haproxy")then
    o:value("__haproxy__", translate("Load Balancing"))
end
for _,key in pairs(key_table) do o:value(key,server_table[key]) end
o.default = "nil"
o.rmempty = false

o = s:option(ListValue, "udp_relay_server", translate("Game Mode UDP Server"))
o:value("", translate("Disable"))
o:value("same", translate("Same as Global Server"))
for _,key in pairs(key_table) do o:value(key,server_table[key]) end

o = s:option(Flag, "v2ray_flow",  translate("Open v2ray split-flow") .."</font>")
o.rmempty = false
o.description = ("<font color='red'>" ..translate("When open v2ray split-flow,your main server must be a v2ray server").."</font>")

o = s:option(ListValue, "youtube_server", translate("Youtube Proxy"))
o:value("nil", translate("Same as Global Server"))
for _,key in pairs(key_table_v2) do o:value(key,v2ray_table[key]) end
o:depends("v2ray_flow", "1")
o.default = "nil"

o = s:option(ListValue, "tw_video_server", translate("TaiWan Video Proxy"))
o:value("nil", translate("Same as Global Server"))
for _,key in pairs(key_table_v2) do o:value(key,v2ray_table[key]) end
o:depends("v2ray_flow", "1")
o.default = "nil"

o = s:option(ListValue, "netflix_server", translate("Netflix Proxy"))
o:value("nil", translate("Same as Global Server"))
for _,key in pairs(key_table_v2) do o:value(key,v2ray_table[key]) end
o:depends("v2ray_flow", "1")
o.default = "nil"

o = s:option(ListValue, "disney_server", translate("Diseny+ Proxy"))
o:value("nil", translate("Same as Global Server"))
for _,key in pairs(key_table_v2) do o:value(key,v2ray_table[key]) end
o:depends("v2ray_flow", "1")
o.default = "nil"

o = s:option(ListValue, "prime_server", translate("Prime Video Proxy"))
o:value("nil", translate("Same as Global Server"))
for _,key in pairs(key_table_v2) do o:value(key,v2ray_table[key]) end
o:depends("v2ray_flow", "1")
o.default = "nil"

o = s:option(ListValue, "tvb_server", translate("TVB Video Proxy"))
o:value("nil", translate("Same as Global Server"))
for _,key in pairs(key_table_v2) do o:value(key,v2ray_table[key]) end
o:depends("v2ray_flow", "1")
o.default = "nil"

o = s:option(ListValue, "threads", translate("Multi Threads Option"))
o:value("0", translate("Auto Threads"))
o:value("1", translate("1 Thread"))
o:value("2", translate("2 Threads"))
o:value("4", translate("4 Threads"))
o:value("8", translate("8 Threads"))
o:value("16", translate("16 Threads"))
o:value("32", translate("32 Threads"))
o:value("64", translate("64 Threads"))
o:value("128", translate("128 Threads"))
o.default = "0"
o.rmempty = false

o = s:option(ListValue, "run_mode", translate("Running Mode"))
o:value("gfw", translate("GFW List Mode"))
o:value("router", translate("IP Route Mode"))
o:value("routers", translate("Oversea IP Route Mode"))
o:value("oversea", translate("Oversea GFW List Mode"))
o:value("all", translate("Global Mode"))
o.default = gfw

o = s:option(ListValue, "dports", translate("Proxy Ports"))
o:value("1", translate("All Ports"))
o:value("2", translate("Only Common Ports"))
o.default = 1

o = s:option(ListValue, "pdnsd_enable", translate("Resolve Dns Mode"))
o:value("0", translate("Use Local DNS Service listen port 5335"))
o:value("1", translate("Use Pdnsd tcp query and cache"))
if nixio.fs.access("/usr/bin/dnsforwarder") then
o:value("3", translate("Use dnsforwarder tcp query and cache"))
end
if nixio.fs.access("/usr/bin/dnscrypt-proxy") then
o:value("5", translate("Use dnscrypt-proxy query and cache"))
end
if nixio.fs.access("/usr/bin/chinadns") then
o:value("6", translate("Use chinadns query and cache"))
end
if nixio.fs.access("/usr/bin/dns2socks") then
o:value("7", translate("Use DNS2SOCKS query and cache"))
end
o.default = 1

o = s:option(ListValue, "chinadns_enable", translate("Chiadns Resolve Dns Mode"))
o:value("0", translate("Use Local DNS Service"))
o:value("1", translate("Use Pdnsd tcp query and cache"))
if nixio.fs.access("/usr/bin/dnsforwarder") then
o:value("3", translate("Use dnsforwarder tcp query and cache"))
end
if nixio.fs.access("/usr/bin/dnscrypt-proxy") then
o:value("5", translate("Use dnscrypt-proxy query and cache"))
end

if nixio.fs.access("/usr/sbin/smartdns") then
o:value("6", translate("Use smartdns query and cache"))
end

if nixio.fs.access("/usr/sbin/https_dns_proxy") then
o:value("7", translate("Use https_dns_proxy query and cache"))
end
o.default = 1
o:depends("pdnsd_enable", "6")

o = s:option(Value, "tunnel_forward", translate("Anti-pollution DNS Server"))
o:value("0.0.0.0:53", translate("Using System Default DNS"))
o:value("0.0.0.0:5333", translate("Using acceleration center DNS"))
o:value("8.8.4.4:53", translate("Google Public DNS (8.8.4.4)"))
o:value("8.8.8.8:53", translate("Google Public DNS (8.8.8.8)"))
o:value("208.67.222.222:53", translate("OpenDNS (208.67.222.222)"))
o:value("208.67.220.220:53", translate("OpenDNS (208.67.220.220)"))
o:value("209.244.0.3:53", translate("Level 3 Public DNS (209.244.0.3)"))
o:value("209.244.0.4:53", translate("Level 3 Public DNS (209.244.0.4)"))
o:value("4.2.2.1:53", translate("Level 3 Public DNS (4.2.2.1)"))
o:value("4.2.2.2:53", translate("Level 3 Public DNS (4.2.2.2)"))
o:value("4.2.2.3:53", translate("Level 3 Public DNS (4.2.2.3)"))
o:value("4.2.2.4:53", translate("Level 3 Public DNS (4.2.2.4)"))
o:value("1.1.1.1:53", translate("Cloudflare DNS (1.1.1.1)"))
o:value("114.114.114.114:53", translate("Oversea Mode DNS-1 (114.114.114.114)"))
o:value("114.114.115.115:53", translate("Oversea Mode DNS-2 (114.114.115.115)"))
o:depends("pdnsd_enable", "1")
o:depends("pdnsd_enable", "2")
o:depends("pdnsd_enable", "3")
o:depends("pdnsd_enable", "4")
o:depends("pdnsd_enable", "5")
o:depends("pdnsd_enable", "6")
o:depends("pdnsd_enable", "7")
o.default = "8.8.4.4:53"


o = s:option(Button,"gfw_data",translate("GFW List Data"))
o.rawhtml  = true
o.template = "vssr/refresh"
o.value =tostring(math.ceil(gfw_count)) .. " " .. translate("Records")

o = s:option(Button,"ad_data",translate("Advertising Data")) 
o .rawhtml  = true
o .template = "vssr/refresh"
o .value =tostring(math.ceil(ad_count)) .. " " .. translate("Records")

o = s:option(Button,"ip_data",translate("China IP Data"))
o.rawhtml  = true
o.template = "vssr/refresh"
o.value =ip_count .. " " .. translate("Records")

o = s:option(Button,"check_port",translate("Check Server Port"))
o.template = "vssr/checkport"
o.value =translate("No Check")
m:section(SimpleSection).template  = "vssr/status2"

return m
