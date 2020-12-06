local d = require "luci.dispatcher"
local uci = require"luci.model.uci".cursor()
local api = require "luci.model.cbi.passwall.api.api"
local appname = "passwall"

local nodes_table = {}
for k, e in ipairs(api.get_valid_nodes()) do
    nodes_table[#nodes_table + 1] = {
        id = e[".name"],
        remarks = e.remarks_name
    }
end

local socks_table = {}
uci:foreach(appname, "socks", function(s)
    if s.enabled == "1" and s.node then
        local id, remarks
        local same, i = s.node:match("^(tcp)([1-9])$")
        if same then
            remarks = translatef("Same as the tcp %s node", i)
        else
            for k, n in pairs(nodes_table) do
                if (s.node == n.id) then
                    remarks = n.remarks; break
                end
            end
        end
        id = "0.0.0.0" .. ":" .. s.port
        socks_table[#socks_table + 1] = {
            id = id,
            remarks = id .. " - " .. (remarks or translate("Misconfigured"))
        }
    end
end)

local doh_validate = function(self, value, t)
    if value ~= "" then
        local flag = 0
        local util = require "luci.util"
        local val = util.split(value, ",")
        local url = val[1]
        val[1] = nil
        for i = 1, #val do
            local v = val[i]
            if v then
                if not datatypes.ipmask4(v) then
                    flag = 1
                end
            end
        end
        if flag == 0 then
            return value
        end
    end
    return nil, translate("DoH request address") .. " " .. translate("Format must be:") .. " URL,IP"
end

m = Map(appname)
local status = m:get("@global_other[0]", "status") or ""
if status:find("big_icon") then
    m:append(Template(appname .. "/global/status"))
else
    m:append(Template(appname .. "/global/status2"))
end

s = m:section(TypedSection, "global")
s.anonymous = true
s.addremove = false

s:tab("Main", translate("Main"))

-- [[ Global Settings ]]--
o = s:taboption("Main", Flag, "enabled", translate("Main switch"))
o.rmempty = false

---- TCP Node
local tcp_node_num = tonumber(m:get("@global_other[0]", "tcp_node_num") or 1)
for i = 1, tcp_node_num, 1 do
    o = s:taboption("Main", ListValue, "tcp_node" .. i, translate("TCP Node") .. " " .. i)
    if i == 1 then
        o.title = translate("TCP Node")
        o.description = translate("For proxy specific list.") .. o.description
        if tonumber(m:get("@auto_switch[0]", "enable") or 0) == 1 then
            local current_node = luci.sys.exec(string.format("[ -f '/var/etc/%s/id/TCP_%s' ] && echo -n $(cat /var/etc/%s/id/TCP_%s)", appname, i, appname, i))
            if current_node and current_node ~= "" and current_node ~= "nil" then
                local e = uci:get_all(appname, current_node)
                if e then
                    local remarks = ""
                    if e.protocol and (e.protocol == "_balancing" or e.protocol == "_shunt") then
                        remarks = "%s：[%s] " % {translatef(e.type .. e.protocol), e.remarks}
                    else
                        if e.use_kcp and e.use_kcp == "1" then
                            remarks = "%s+%s：[%s] %s" % {e.type, "Kcptun", e.remarks, e.address}
                        else
                            remarks = "%s：[%s] %s:%s" % {e.type, e.remarks, e.address, e.port}
                        end
                    end
                    local url = d.build_url("admin", "services", appname, "node_config", current_node)
                    o.description = translate("For proxy specific list.") .. "<br />" .. translatef("Current node: %s", string.format('<a href="%s">%s</a>', url, remarks))
                end
            end
        end
    end
    o:value("nil", translate("Close"))
    for k, v in pairs(nodes_table) do o:value(v.id, v.remarks) end
end

---- UDP Node
local udp_node_num = tonumber(m:get("@global_other[0]", "udp_node_num") or 1)
for i = 1, udp_node_num, 1 do
    o = s:taboption("Main", ListValue, "udp_node" .. i, translate("UDP Node") .. " " .. i)
    o:value("nil", translate("Close"))
    if i == 1 then
        o.title = translate("UDP Node")
        o.description = translate("For proxy game network, DNS hijack etc.") .. o.description .. "<br />" .. translate("The selected server will not use Kcptun.")
        o:value("tcp_", translate("Same as the tcp node"))
        --o:value("tcp", translate("Same as the tcp node"))
        --o:value("tcp_", translate("Same as the tcp node") .. "（" .. translate("New process") .. "）")
    end
    for k, v in pairs(nodes_table) do o:value(v.id, v.remarks) end
end

s:tab("DNS", translate("DNS"))

if api.is_finded("chinadns-ng") then
    o = s:taboption("DNS", Flag, "chinadns_ng", translate("Use ChinaDNS-NG"), translate("When checked, forced to be set to dnsmasq upstream DNS."))
    o.default = "0"

    o = s:taboption("DNS", Flag, "fair_mode", translate("ChinaDNS-NG Fair Mode"))
    o.default = "1"
    o:depends("chinadns_ng", "1")
end

o = s:taboption("DNS", Value, "up_china_dns", translate("Resolver For Local/WhiteList Domains") .. "(UDP)")
o.description = translate("IP:Port mode acceptable, multi value split with english comma.") .. "<br />" .. translate("When the selection is not the default, this DNS is forced to be set to dnsmasq upstream DNS.")
o.default = "default"
o:value("default", translate("Default"))
if api.is_finded("https-dns-proxy") then
    o:value("https-dns-proxy", "https-dns-proxy(DoH)")
end
o:value("223.5.5.5", "223.5.5.5 (" .. translate("Ali") .. "DNS)")
o:value("223.6.6.6", "223.6.6.6 (" .. translate("Ali") .. "DNS)")
o:value("114.114.114.114", "114.114.114.114 (114DNS)")
o:value("114.114.115.115", "114.114.115.115 (114DNS)")
o:value("119.29.29.29", "119.29.29.29 (DNSPOD DNS)")
o:value("182.254.116.116", "182.254.116.116 (DNSPOD DNS)")
o:value("1.2.4.8", "1.2.4.8 (CNNIC DNS)")
o:value("210.2.4.8", "210.2.4.8 (CNNIC DNS)")
o:value("180.76.76.76", "180.76.76.76 (" .. translate("Baidu") .. "DNS)")

---- DoH
o = s:taboption("DNS", Value, "up_china_dns_doh", translate("DoH request address"))
o:value("https://dns.alidns.com/dns-query,223.5.5.5,223.6.6.6", "AliDNS")
o:value("https://doh.pub/dns-query,119.29.29.29,119.28.28.28", "DNSPod")
o.default = "https://dns.alidns.com/dns-query,223.5.5.5,223.6.6.6"
o.validate = doh_validate
o:depends("up_china_dns", "https-dns-proxy")

---- DNS Forward Mode
o = s:taboption("DNS", ListValue, "dns_mode", translate("Filter Mode"))
o.rmempty = false
o:reset_values()
if api.is_finded("pdnsd") then
    o:value("pdnsd", "pdnsd")
end
if api.is_finded("dns2socks") then
    o:value("dns2socks", "dns2socks")
end
if api.is_finded("https-dns-proxy") then
    o:value("https-dns-proxy", "https-dns-proxy(DoH)")
end
o:value("udp", translatef("Requery DNS By %s", translate("UDP Node")))
o:value("nonuse", translate("No Filter"))
o:value("custom", translate("Custom DNS"))

---- Custom DNS
o = s:taboption("DNS", Value, "custom_dns", translate("Custom DNS"))
o.default = "127.0.0.1#5353"
o.validate = function(self, value, t)
    local v = string.gsub(value, "#", ":")
    if not datatypes.ipaddrport(v) then
        return nil, translate("Custom DNS") .. " " .. translate("Not valid IP format, please re-enter!")
    end
    return value
end
o:depends({dns_mode = "custom"})

o = s:taboption("DNS", ListValue, "up_trust_pdnsd_dns", translate("Resolver For The List Proxied"))
-- o.description = translate("You can use other resolving DNS services as trusted DNS, Example: dns2socks, dns-forwarder... 127.0.0.1#5353<br />Only use two at most, english comma separation, If you do not fill in the # and the following port, you are using port 53.")
o.default = "tcp"
o:value("tcp", translatef("Requery DNS By %s", translate("TCP Node")))
o:value("udp", translatef("Requery DNS By %s", translate("UDP Node")))
o:depends("dns_mode", "pdnsd")

o = s:taboption("DNS", ListValue, "up_trust_doh_dns", translate("Resolver For The List Proxied"))
o:value("tcp", translatef("Requery DNS By %s", translate("TCP Node")))
o:value("socks", translatef("Requery DNS By %s", translate("Socks Node")))
o:depends("dns_mode", "https-dns-proxy")

o = s:taboption("DNS", Value, "socks_server", translate("Socks Server"), translate("Make sure socks service is available on this address."))
for k, v in pairs(socks_table) do o:value(v.id, v.remarks) end
o.validate = function(self, value, t)
    if not datatypes.ipaddrport(value) then
        return nil, translate("Socks Server") .. " " .. translate("Not valid IP format, please re-enter!")
    end
    return value
end
o:depends({dns_mode = "dns2socks"})
o:depends({dns_mode = "https-dns-proxy", up_trust_doh_dns = "socks"})

---- DoH
o = s:taboption("DNS", Value, "up_trust_doh", translate("DoH request address"))
o:value("https://dns.adguard.com/dns-query,176.103.130.130,176.103.130.131", "AdGuard")
o:value("https://cloudflare-dns.com/dns-query,1.1.1.1,1.0.0.1", "Cloudflare")
o:value("https://security.cloudflare-dns.com/dns-query,1.1.1.2,1.0.0.2", "Cloudflare-Security")
o:value("https://doh.opendns.com/dns-query,208.67.222.222,208.67.220.220", "OpenDNS")
o:value("https://dns.google/dns-query,8.8.8.8,8.8.4.4", "Google")
o:value("https://doh.libredns.gr/dns-query,116.202.176.26", "LibreDNS")
o:value("https://doh.libredns.gr/ads,116.202.176.26", "LibreDNS (No Ads)")
o:value("https://dns.quad9.net/dns-query,9.9.9.9,149.112.112.112", "Quad9-Recommended")
o.default = "https://dns.google/dns-query,8.8.8.8,8.8.4.4"
o.validate = doh_validate
o:depends({dns_mode = "https-dns-proxy"})

---- DNS Forward
o = s:taboption("DNS", Value, "dns_forward", translate("Filtered DNS(For Proxied Domains)"), translate("IP:Port mode acceptable, the 1st for 'dns2socks' if split with english comma."))
o.default = "8.8.4.4"
o:value("8.8.4.4", "8.8.4.4 (Google DNS)")
o:value("8.8.8.8", "8.8.8.8 (Google DNS)")
o:value("208.67.222.222", "208.67.222.222 (Open DNS)")
o:value("208.67.220.220", "208.67.220.220 (Open DNS)")
o:depends({dns_mode = "dns2socks"})
o:depends({dns_mode = "pdnsd"})
o:depends({dns_mode = "udp"})

--[[
o = s:taboption("DNS", Flag, "dns_cache", translate("Cache Resolved"))
o.default = "1"
o:depends({dns_mode = "dns2socks"})
o:depends({dns_mode = "pdnsd"})
]]--

o = s:taboption("DNS", Flag, "use_chnlist", translate("Use ChinaList"), translate("Only useful in non-gfwlist mode.") .. "<br />" .. translate("When used, the domestic DNS will be used only when the chnlist rule is hit, and the domain name that misses the rule will be resolved by remote DNS."))
o.default = "0"

o = s:taboption("DNS", Button, "clear_ipset", translate("Clear IPSET"), translate("Try this feature if the rule modification does not take effect."))
o.inputstyle = "remove"
function o.write(e, e)
    luci.sys.call("/etc/init.d/" .. appname .. " stop && /usr/share/" .. appname .. "/iptables.sh flush_ipset && /etc/init.d/" .. appname .. " restart")
end

s:tab("Proxy", translate("Mode"))

---- TCP Default Proxy Mode
o = s:taboption("Proxy", ListValue, "tcp_proxy_mode", "TCP" .. translate("Default") .. translate("Proxy Mode"))
-- o.description = translate("If not available, try clearing the cache.")
o.default = "chnroute"
o.rmempty = false
o:value("disable", translate("No Proxy"))
o:value("global", translate("Global Proxy"))
o:value("gfwlist", translate("GFW List"))
o:value("chnroute", translate("Not China List"))
o:value("returnhome", translate("China List"))

---- UDP Default Proxy Mode
o = s:taboption("Proxy", ListValue, "udp_proxy_mode", "UDP" .. translate("Default") .. translate("Proxy Mode"))
o.default = "chnroute"
o.rmempty = false
o:value("disable", translate("No Proxy"))
o:value("global", translate("Global Proxy"))
o:value("gfwlist", translate("GFW List"))
o:value("chnroute", translate("Game Mode"))
o:value("returnhome", translate("China List"))

---- Localhost TCP Proxy Mode
o = s:taboption("Proxy", ListValue, "localhost_tcp_proxy_mode", translate("Router Localhost") .. "TCP" .. translate("Proxy Mode"))
-- o.description = translate("The server client can also use this rule to scientifically surf the Internet.")
o:value("default", translate("Default"))
o:value("global", translate("Global Proxy"))
o:value("gfwlist", translate("GFW List"))
o:value("chnroute", translate("Not China List"))
o:value("returnhome", translate("China List"))
o.default = "default"
o.rmempty = false

---- Localhost UDP Proxy Mode
o = s:taboption("Proxy", ListValue, "localhost_udp_proxy_mode", translate("Router Localhost") .. "UDP" .. translate("Proxy Mode"))
o:value("default", translate("Default"))
o:value("global", translate("Global Proxy"))
o:value("gfwlist", translate("GFW List"))
o:value("chnroute", translate("Game Mode"))
o:value("returnhome", translate("China List"))
o:value("disable", translate("No Proxy"))
o.default = "default"
o.rmempty = false

s:tab("tips", translate("Tips"))

o = s:taboption("tips", DummyValue, "")
o.template = appname .. "/global/tips"

-- [[ Socks Server ]]--
s = m:section(TypedSection, "socks", translate("Socks Config"))
s.anonymous = true
s.addremove = true
s.template = "cbi/tblsection"
function s.create(e, t)
    TypedSection.create(e, api.gen_uuid())
end

o = s:option(DummyValue, "status", translate("Status"))
o.rawhtml = true
o.cfgvalue = function(t, n)
    return string.format('<div class="_status" socks_id="%s"></div>', n)
end

---- Enable
o = s:option(Flag, "enabled", translate("Enable"))
o.default = 1
o.rmempty = false

o = s:option(ListValue, "node", translate("Socks Node"))
local tcp_node_num = tonumber(m:get("@global_other[0]", "tcp_node_num") or 1)
for i = 1, tcp_node_num, 1 do
    o:value("tcp" .. i, translatef("Same as the tcp %s node", i))
end
for k, v in pairs(nodes_table) do o:value(v.id, v.remarks) end

o = s:option(Value, "port", "Socks" .. translate("Listen Port"))
o.default = 9050
o.datatype = "port"
o.rmempty = false

if api.is_finded("xray") or api.is_finded("v2ray") then
    o = s:option(Value, "http_port", "HTTP" .. translate("Listen Port") .. " " .. translate("0 is not use"))
    o.default = 0
    o.datatype = "port"
end

m:append(Template(appname .. "/global/footer"))

--[[
local apply = luci.http.formvalue("cbi.apply")
if apply then
os.execute("/etc/init.d/" .. appname .." restart")
end
--]]

return m
