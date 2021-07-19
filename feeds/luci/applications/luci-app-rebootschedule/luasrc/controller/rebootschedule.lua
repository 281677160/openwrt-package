module("luci.controller.rebootschedule", package.seeall)
function index()
if not nixio.fs.access("/etc/config/rebootschedule") then
return
end

entry({"admin", "system", "rebootschedule"}, cbi("rebootschedule"), _("多功能重启"),88)

end
