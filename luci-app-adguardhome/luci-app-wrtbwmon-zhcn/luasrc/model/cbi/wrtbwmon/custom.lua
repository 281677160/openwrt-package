local USER_FILE_PATH = "/etc/wrtbwmon.user"

local fs = require "nixio.fs"

local f = SimpleForm("wrtbwmon", 
    "流量统计 - 自定义", 
    "本配置可根据 MAC 地址自定义主机备注名"
    .. "每一行格式必须按照此格式配置: \"00:aa:bb:cc:ee:ff,主机备注名\"。")

local o = f:field(Value, "_custom")

o.template = "cbi/tvalue"
o.rows = 20

function o.cfgvalue(self, section)
    return fs.readfile(USER_FILE_PATH)
end

function o.write(self, section, value)
    value = value:gsub("\r\n?", "\n")
    fs.writefile(USER_FILE_PATH, value)
end

return f
