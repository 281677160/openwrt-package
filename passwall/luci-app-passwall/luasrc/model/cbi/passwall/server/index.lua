local d = require "luci.dispatcher"
local _api = require "luci.model.cbi.passwall.api.api"
local e = luci.model.uci.cursor()

m = Map("passwall_server", translate("Server-Side"))

t = m:section(NamedSection, "global", "global")
t.anonymous = true
t.addremove = false

e = t:option(Flag, "enable", translate("Enable"))
e.rmempty = false

t = m:section(TypedSection, "user", translate("Users Manager"))
t.anonymous = true
t.addremove = true
t.sortable = true
t.template = "cbi/tblsection"
t.extedit = d.build_url("admin", "services", "passwall", "server_user", "%s")
function t.create(e, t)
    local uuid = _api.gen_uuid()
    t = uuid
    TypedSection.create(e, t)
    luci.http.redirect(e.extedit:format(t))
end
function t.remove(e, t)
    e.map.proceed = true
    e.map:del(t)
    luci.http.redirect(d.build_url("admin", "services", "passwall", "server"))
end

e = t:option(Flag, "enable", translate("Enable"))
e.width = "5%"
e.rmempty = false

e = t:option(DummyValue, "status", translate("Status"))
e.rawhtml = true
e.cfgvalue = function(t, n)
    return string.format('<font class="_users_status">%s</font>', translate("Collecting data..."))
end

e = t:option(DummyValue, "remarks", translate("Remarks"))
e.width = "15%"

---- Type
e = t:option(DummyValue, "type", translate("Type"))
e.cfgvalue = function(t, n)
    local v = Value.cfgvalue(t, n)
    if v then
        if v == "Xray" or v == "V2ray" then
            local protocol = m:get(n, "protocol")
            return v .. " -> " .. protocol
        end
        return v
    end
end

e = t:option(DummyValue, "port", translate("Port"))

m:append(Template("passwall/server/log"))

m:append(Template("passwall/server/users_list_status"))
return m

