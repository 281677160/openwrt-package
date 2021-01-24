local e = require "luci.sys"
local net = require "luci.model.network".init()
local api = require "luci.model.cbi.passwall.api.api"
local appname = api.appname

local nodes_table = {}
for k, e in ipairs(api.get_valid_nodes()) do
    if e.node_type == "normal" then
        nodes_table[#nodes_table + 1] = {
            id = e[".name"],
            obj = e,
            remarks = e.remarks_name
        }
    end
end

m = Map(appname)

-- [[ Haproxy Settings ]]--
s = m:section(TypedSection, "global_haproxy")
s.anonymous = true

s:append(Template(appname .. "/haproxy/status"))

---- Balancing Enable
o = s:option(Flag, "balancing_enable", translate("Enable Load Balancing"))
o.rmempty = false
o.default = false

---- Console Username
o = s:option(Value, "console_user", translate("Console Username"))
o.default = ""
o:depends("balancing_enable", 1)

---- Console Password
o = s:option(Value, "console_password", translate("Console Password"))
o.password = true
o.default = ""
o:depends("balancing_enable", 1)

---- Console Port
o = s:option(Value, "console_port", translate("Console Port"), translate(
                 "In the browser input routing IP plus port access, such as:192.168.1.1:1188"))
o.default = "1188"
o:depends("balancing_enable", 1)

-- [[ Balancing Settings ]]--
s = m:section(TypedSection, "haproxy_config", "",
              "<font color='red'>" .. 
              translate("Add a node, Export Of Multi WAN Only support Multi Wan. Load specific gravity range 1-256. Multiple primary servers can be load balanced, standby will only be enabled when the primary server is offline! Multiple groups can be set, Haproxy port same one for each group.") ..
              "\n" .. translate("Note that the node configuration parameters for load balancing must be consistent, otherwise problems can arise!") ..
              "</font>")
s.template = "cbi/tblsection"
s.sortable = true
s.anonymous = true
s.addremove = true

---- Enable
o = s:option(Flag, "enabled", translate("Enable"))
o.default = 1
o.rmempty = false

---- Node Address
o = s:option(Value, "lbss", translate("Node Address"))
for k, v in pairs(nodes_table) do o:value(v.obj.address .. ":" .. v.obj.port, v.remarks) end
o.rmempty = false

---- Node Port
o = s:option(Value, "lbort", translate("Node Port"))
o:value("default", translate("Default"))
o.default = "default"
o.rmempty = false

---- Haproxy Port
o = s:option(Value, "haproxy_port", translate("Haproxy Port"))
o.default = "1181"
o.rmempty = false

---- Node Weight
o = s:option(Value, "lbweight", translate("Node Weight"))
o.default = "5"
o.rmempty = false

---- Export
--[[
o = s:option(ListValue, "export", translate("Export Of Multi WAN"))
o:value(0, translate("Auto"))
local ifaces = e.net:devices()
for _, iface in ipairs(ifaces) do
    if (iface:match("^br") or iface:match("^eth*") or iface:match("^pppoe*")) then
        local nets = net:get_interface(iface)
        nets = nets and nets:get_networks() or {}
        for k, v in pairs(nets) do nets[k] = nets[k].sid end
        nets = table.concat(nets, ",")
        o:value(iface, ((#nets > 0) and "%s (%s)" % {iface, nets} or iface))
    end
end
o.default = 0
o.rmempty = false
]]--

---- Mode
o = s:option(ListValue, "backup", translate("Mode"))
o:value(0, translate("Primary"))
o:value(1, translate("Standby"))
o.rmempty = false

return m
