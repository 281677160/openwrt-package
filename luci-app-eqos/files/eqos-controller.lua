module("luci.controller.eqos", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/eqos") then
		return
	end
	
	local page

	page = entry({"admin", "services", "eqos"}, cbi("eqos"), "EQoS")
	page.dependent = true
end
