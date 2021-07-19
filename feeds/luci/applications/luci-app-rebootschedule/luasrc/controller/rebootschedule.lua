module("luci.controller.rebootschedule", package.seeall)
function index()
	if not nixio.fs.access("/etc/config/rebootschedule") then
		return
	end
	
	entry({"admin", "system"}, firstchild(), "系统", 44).dependent = false
	entry({"admin", "system", "rebootschedule"}, cbi("rebootschedule"), "定时设置", 20).dependent = true
end



