local m = Map("wrtbwmon", "流量统计 - 配置")

local s = m:section(NamedSection, "general", "wrtbwmon", "常规选项")

local o = s:option(Flag, "persist", "可保留数据",
    "启用本项可将统计数据保存至 /etc/config 目录， "
    .. "即使固件更新后依然可以保留原有数据")
o.rmempty = false

function o.write(self, section, value)
    if value == '1' then
        luci.sys.call("mv /tmp/usage.db /etc/config/usage.db")
    elseif value == '0' then
        luci.sys.call("mv /etc/config/usage.db /tmp/usage.db")
    end
    return Flag.write(self, section ,value)
end

return m
