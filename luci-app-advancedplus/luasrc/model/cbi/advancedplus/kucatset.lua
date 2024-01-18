local a, t, e
a = Map("advancedplus")
a.title = translate("KuCat Theme Config")
a.description = translate("Set and manage features such as KuCat themed background wallpaper, main background color, partition background, transparency, blur, toolbar retraction and shortcut pointing.</br>")..
translate("There are 6 preset color schemes, and only the desktop background image can be set to display or not. The custom color values are RGB values such as 255,0,0 (representing red), and a blur radius of 0 indicates no lag in the image.")..
translate("</br>")..translate("<a href=\'' target=\'_blank\'></a>")
t = a:section(TypedSection, "basic", translate("Settings"))
t.anonymous = true

e = t:option(ListValue, 'background', translate('Wallpaper Source'),translate('Local wallpapers need to be uploaded on their own, and only the first update downloaded on the same day will be automatically downloaded.'))
e:value('0', translate('Local wallpaper'))
--e:value('1', translate('Online Bing wallpaper'))
e:value('2', translate('Auto download unsplash wallpaper'))
e:value('3', translate('Auto download Bing wallpaper'))
e:value('4', translate('Auto download Bird 4K wallpaper'))
e.default = '0'
e.rmempty = false

e = t:option(Flag, "bklock", translate("Wallpaper synchronization"),translate("Is the login wallpaper consistent with the desktop wallpaper? If not selected, it indicates that the desktop wallpaper and login wallpaper are set independently."))
e.rmempty = false
e.default = '0'

e = t:option(Flag, "setbar", translate("Expand Toolbar"),translate('Expand or shrink the toolbar'))
e.rmempty = false
e.default = '0'

e = t:option(Flag, "bgqs", translate("Refreshing mode"),translate('Cancel background glass fence special effects'))
e.rmempty = false
e.default = '0'

e = t:option(Flag, "dayword", translate("Enable Daily Word"))
e.rmempty = false
e.default = '0'

e = t:option(Value, 'gohome', translate('Status Homekey settings'))
e:value('overview', translate('Overview'))
e:value('online', translate('Online User'))
e:value('realtime', translate('Realtime Graphs'))
e:value('netdata', translate('NetData'))
e.default = 'overview'
e.rmempty = false

e = t:option(Value, 'gouser', translate('System Userkey settings'))
e:value('advancedplus', translate('Advanced plus'))
e:value('netwizard', translate('Inital Setup'))
e:value('system', translate('System'))
e:value('admin', translate('Administration'))
e:value('terminal', translate('TTYD Terminal'))
e:value('packages', translate('Software'))
e:value('filetransfer', translate('FileTransfer'))
e.default = 'advancedplus'
e.rmempty = false

e = t:option(Value, 'gossr', translate('Services Ssrkey settings'))
e:value('shadowsocksr', translate('SSR'))
e:value('bypass', translate('bypass'))
e:value('vssr', translate('Hello World'))
e:value('passwall', translate('passwall'))
e:value('passwall2', translate('passwall2'))
e:value('openclash', translate('OpenClash'))
e:value('chatgpt-web', translate('Chatgpt Web'))
e:value('ddns-go', translate('DDNS-GO'))
e.default = 'bypass'
e.rmempty = false

e = t:option(Flag, "fontmode", translate("Care mode (large font)"))
e.rmempty = false
e.default = '0'

-- e = t:option(DummyValue, '', translate('Color palette'))
-- e.rawhtml = true
-- e.template = 'advancedplus/color_primary'

t = a:section(TypedSection, "theme", translate("Color scheme list"))
t.template = "cbi/tblsection"
t.anonymous = true
t.addremove = true

e = t:option(Value, 'remarks', translate('Remarks'))

e = t:option(Flag, "use", translate("Enable color matching"))
e.rmempty = false
e.default = '1'

e = t:option(ListValue, 'mode', translate('Theme mode'))
e:value('light', translate('Light'))
e:value('dark', translate('Dark'))
e.default = 'light'

e = t:option(Value, 'primary_rgbm', translate('Main Background color(RGB)'))
e:value("blue",translate("RoyalBlue"))
e:value("green",translate("MediumSeaGreen"))
e:value("orange",translate("SandyBrown"))
e:value("red",translate("TomatoRed"))
e:value("gray",translate("Grayscale spatiotemporal"))
e:value("bluets",translate("Cool Ocean Heart (transparent and bright)"))
e.default='green'
e.default='74,161,133'

e = t:option(Flag, "bkuse", translate("Enable wallpaper"))
e.rmempty = false
e.default = '1'

e = t:option(Value, 'primary_rgbm_ts', translate('Wallpaper transparency'))
e:value("0",translate("0"))
e:value("0.1",translate("0.1"))
e:value("0.2",translate("0.2"))
e:value("0.3",translate("0.3"))
e:value("0.4",translate("0.4"))
e:value("0.5",translate("0.5"))
e:value("0.6",translate("0.6"))
e:value("0.7",translate("0.7"))
e:value("0.8",translate("0.8"))
e:value("0.9",translate("0.9"))
e:value("0.95",translate("0.95"))
e:value("1",translate("1"))
e.default='0.5'

e = t:option(Value, 'primary_opacity', translate('Wallpaper blur radius'))
e:value("0",translate("0"))
e:value("1",translate("1"))
e:value("2",translate("2"))
e:value("3",translate("3"))
e:value("4",translate("4"))
e:value("5",translate("5"))
e:value("6",translate("6"))
e:value("7",translate("7"))
e:value("8",translate("8"))
e:value("9",translate("9"))
e:value("10",translate("10"))
e:value("20",translate("20"))
e:value("30",translate("30"))
e:value("50",translate("50"))
e:value("80",translate("80"))
e:value("100",translate("100"))
e:value("200",translate("200"))
e.default='10'

e = t:option(Value, 'primary_rgbs', translate('Fence background(RGB)'))
e.default='225,112,88'

e = t:option(Value, 'primary_rgbs_ts', translate('Fence background transparency'))
e:value("0",translate("0"))
e:value("0.05",translate("0.05"))
e:value("0.1",translate("0.1"))
e:value("0.2",translate("0.2"))
e:value("0.3",translate("0.3"))
e:value("0.4",translate("0.4"))
e:value("0.5",translate("0.5"))
e:value("0.6",translate("0.6"))
e:value("0.7",translate("0.7"))
e:value("0.8",translate("0.8"))
e:value("0.9",translate("0.9"))
e:value("0.95",translate("0.95"))
e:value("1",translate("1"))
e.default='0.3'

a.apply_on_parse = true
a.on_after_apply = function(self,map)
	luci.sys.exec("/etc/init.d/advancedplus start >/dev/null 2>&1")
	luci.http.redirect(luci.dispatcher.build_url("admin","system","advancedplus","kucatset"))
end

return a
