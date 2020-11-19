#!/usr/bin/lua
------------------------------------------------
-- This file is part of the luci-app-ssr-plus update.lua
-- By Mattraks
------------------------------------------------
require 'nixio'
require 'luci.util'
require 'luci.jsonc'
require 'luci.sys'
local icount =0
local ucic = luci.model.uci.cursor()

local log = function(...)
	print(os.date("%Y-%m-%d %H:%M:%S ") .. table.concat({ ... }, " "))
end

log('正在更新【GFW列表】数据库')
	refresh_cmd="wget-ssl --no-check-certificate https://cdn.jsdelivr.net/gh/gfwlist/gfwlist/gfwlist.txt -O /tmp/gfw.b64"
	sret=luci.sys.call(refresh_cmd .. " 2>/dev/null")
	if sret== 0 then
	luci.sys.call("/usr/bin/vssr-gfw")
	icount = luci.sys.exec("cat /tmp/gfwnew.txt | wc -l")
	if tonumber(icount)>1000 then
	oldcount=luci.sys.exec("cat /etc/dnsmasq.vssr/gfw_list.conf | wc -l")
		if tonumber(icount) ~= tonumber(oldcount) then
			luci.sys.exec("cp -f /tmp/gfwnew.txt /etc/dnsmasq.vssr/gfw_list.conf")
			luci.sys.exec("cp -f /tmp/gfwnew.txt /tmp/dnsmasq.vssr/gfw_list.conf")
			log('更新成功！ 新的总纪录数：'.. icount)
		else
			log('你已经是最新数据，无需更新！')
		end
	else
	log('更新失败！')
	end
	luci.sys.exec("rm -f /tmp/gfwnew.txt")
else
	log('更新失败！')
end

log('正在更新【国内IP段】数据库')
if (ucic:get_first('vssr', 'global', 'chnroute','0') == '1' ) then
	refresh_cmd="wget-ssl --no-check-certificate -O - ".. ucic:get_first('vssr', 'global', 'chnroute_url','https://ispip.clang.cn/all_cn.txt') .." > /tmp/china_ssr.txt 2>/dev/null"
else
	refresh_cmd="wget -O- 'http://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest'  2>/dev/null| awk -F\\| '/CN\\|ipv4/ { printf(\"%s/%d\\n\", $4, 32-log($5)/log(2)) }' > /tmp/china_ssr.txt"
end
sret=luci.sys.call(refresh_cmd)
icount = luci.sys.exec("cat /tmp/china_ssr.txt | wc -l")
if sret== 0 then
	icount = luci.sys.exec("cat /tmp/china_ssr.txt | wc -l")
	if tonumber(icount)>1000 then
		oldcount=luci.sys.exec("cat /etc/china_ssr.txt | wc -l")
		if tonumber(icount) ~= tonumber(oldcount) then
			luci.sys.exec("cp -f /tmp/china_ssr.txt /etc/china_ssr.txt")
			log('更新成功！ 新的总纪录数：'.. icount)
		else
			log('你已经是最新数据，无需更新！')
		end
	else
		log('更新失败！')
	end
	luci.sys.exec("rm -f /tmp/china_ssr.txt")
else
	log('更新失败！')
end

if ucic:get_first('vssr', 'global', 'adblock','0') == "1" then
log('正在更新【广告屏蔽】数据库')
if nixio.fs.access("/usr/bin/wget-ssl") then
	refresh_cmd="wget-ssl --no-check-certificate -O - ".. ucic:get_first('vssr', 'global', 'adblock_url','https://easylist-downloads.adblockplus.org/easylistchina+easylist.txt') .." > /tmp/adnew.conf"
end
sret=luci.sys.call(refresh_cmd .. " 2>/dev/null")
if sret== 0 then
	luci.sys.call("/usr/bin/vssr-ad")
	icount = luci.sys.exec("cat /tmp/ad.conf | wc -l")
	if tonumber(icount)>1000 then
	if nixio.fs.access("/etc/dnsmasq.vssr/ad.conf") then
		oldcount=luci.sys.exec("cat /etc/dnsmasq.vssr/ad.conf | wc -l")
	else
		oldcount=0
	end
	if tonumber(icount) ~= tonumber(oldcount) then
		luci.sys.exec("cp -f /tmp/ad.conf /etc/dnsmasq.vssr/ad.conf")
		luci.sys.exec("cp -f /tmp/ad.conf /tmp/dnsmasq.vssr/ad.conf")
		log('更新成功！ 新的总纪录数：'.. icount)
	else
		log('你已经是最新数据，无需更新！')
	end
	else
	log('更新失败！')
	end
	luci.sys.exec("rm -f /tmp/ad.conf")
else
	log('更新失败！')
end
end

luci.sys.call("/etc/init.d/dnsmasq restart")
