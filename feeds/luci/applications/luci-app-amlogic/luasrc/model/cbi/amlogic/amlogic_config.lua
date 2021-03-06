local fs = require "luci.fs"
local http = require "luci.http"
local DISP = require "luci.dispatcher"
local b

--Set Default value
default_firmware_repo="ophub/amlogic-s9xxx-openwrt"
local amlogic_firmware_repo = luci.sys.exec("uci get amlogic.config.amlogic_firmware_repo 2>/dev/null") or default_firmware_repo

default_firmware_tag="s9xxx_lede"
local amlogic_firmware_tag = luci.sys.exec("uci get amlogic.config.amlogic_firmware_tag 2>/dev/null") or default_firmware_tag

default_firmware_suffix=".img.gz"
local amlogic_firmware_suffix = luci.sys.exec("uci get amlogic.config.amlogic_firmware_suffix 2>/dev/null") or default_firmware_suffix

default_firmware_config="1"
local amlogic_firmware_config = luci.sys.exec("uci get amlogic.config.amlogic_firmware_config 2>/dev/null") or default_firmware_config

default_kernel_path="amlogic-s9xxx/amlogic-kernel"
local amlogic_kernel_path = luci.sys.exec("uci get amlogic.config.amlogic_kernel_path 2>/dev/null") or default_kernel_path

default_write_bootloader="1"
local amlogic_write_bootloader = luci.sys.exec("uci get amlogic.config.amlogic_write_bootloader 2>/dev/null") or default_write_bootloader

--SimpleForm for Config Source
b = SimpleForm("amlogic_check", translate("Plugin Settings"), nil)
b.description = translate("You can customize the download site of OpenWrt firmware and kernel in [Download Update Online].")
b.reset = false
b.submit = false
s = b:section(SimpleSection, "", nil)

--1.Display config instructions
o=s:option(Flag,"more",translate("View example description:"))
o.rmempty=false

--2.SimpleForm for Check
o = s:option(TextValue, "display_config", nil)
o.template = "amlogic/other_config"
o:depends("more", "1")

--3.Set OpenWrt Firmware Repository
o = s:option(Value, "firmware_repo", translate("OpenWrt Firmware Repository:"))
o.description = translate("Set up the github.com repository of [Download Update Online].")
o.rmempty = true
o.default = amlogic_firmware_repo
o.write = function(self, key, value)
	if value == "" then
        --self.description = translate("Invalid value.")
        amlogic_firmware_repo = default_firmware_repo
	else
        --self.description = translate("OpenWrt Firmware Repository:") .. value
        amlogic_firmware_repo = value
	end
end

--4.Set OpenWrt Releases Tag Keywords
o = s:option(Value, "firmware_tag", translate("OpenWrt Releases Tag Keywords:"))
o.description = translate("Set the keywords of the Releases tag in github.com of [Download Update Online].")
o.rmempty = true
o.default = amlogic_firmware_tag
o.write = function(self, key, value)
	if value == "" then
        --self.description = translate("Invalid value.")
        amlogic_firmware_tag = default_firmware_tag
	else
        --self.description = translate("OpenWrt Releases Tag Keywords:") .. value
        amlogic_firmware_tag = value
	end
end

--5.Set OpenWrt Firmware Suffix
o = s:option(Value, "firmware_suffix", translate("OpenWrt Firmware Suffix:"))
o.description = translate("Set the suffix of OpenWrt firmware in github.com of [Download Update Online].")
o.rmempty = true
o.default = amlogic_firmware_suffix
o.write = function(self, key, value)
	if value == "" then
        --self.description = translate("Invalid value.")
        amlogic_firmware_suffix = default_firmware_suffix
	else
        --self.description = translate("OpenWrt Firmware Suffix:") .. value
        amlogic_firmware_suffix = value
	end
end

--6.Set OpenWrt Kernel DownLoad Path
o = s:option(Value, "kernel_repo", translate("OpenWrt Kernel DownLoad Path:"))
o.description = translate("Set the kernel download path in github.com repository of [Download Update Online].")
o.rmempty = true
o.default = amlogic_kernel_path
o.write = function(self, key, value)
	if value == "" then
        --self.description = translate("Invalid value.")
        amlogic_kernel_path = default_kernel_path
	else
        --self.description = translate("OpenWrt Kernel DownLoad Path:") .. value
        amlogic_kernel_path = value
	end
end

--7.Restore configuration
o = s:option(Flag,"restore_config",translate("Keep config update:"))
o.description = translate("Set whether to restore the current config during [Download Update Online] and [Manually Upload Update].")
o.rmempty = false
if tonumber(amlogic_firmware_config) == 0 then
    o.default = "0"
else
    o.default = "1"
end
o.write = function(self, key, value)
	if value == "1" then
		amlogic_firmware_config = "1"
	else
		amlogic_firmware_config = "0"
	end
end

--8.Write bootloader
o = s:option(Flag,"auto_write_bootloader",translate("Auto write bootloader:"))
o.description = translate("Set whether to auto write bootloader during install and update OpenWrt.")
o.rmempty = false
if tonumber(amlogic_write_bootloader) == 0 then
    o.default = "0"
else
    o.default = "1"
end
o.write = function(self, key, value)
	if value == "1" then
		amlogic_write_bootloader = "1"
	else
		amlogic_write_bootloader = "0"
	end
end

--9.Save button
o = s:option(Button, "", translate("Save Config:"))
o.template = "amlogic/other_button"
o.render = function(self, section, scope)
	self.section = true
	scope.display = ""
	self.inputtitle = translate("Save")
	self.inputstyle = "apply"
	Button.render(self, section, scope)
end
o.write = function(self, section, scope)
	luci.sys.exec("uci set amlogic.config.amlogic_firmware_repo=" .. amlogic_firmware_repo .. " 2>/dev/null")
	luci.sys.exec("uci set amlogic.config.amlogic_firmware_tag=" .. amlogic_firmware_tag .. " 2>/dev/null")
	luci.sys.exec("uci set amlogic.config.amlogic_firmware_suffix=" .. amlogic_firmware_suffix .. " 2>/dev/null")
	luci.sys.exec("uci set amlogic.config.amlogic_firmware_config=" .. amlogic_firmware_config .. " 2>/dev/null")
	luci.sys.exec("uci set amlogic.config.amlogic_kernel_path=" .. amlogic_kernel_path .. " 2>/dev/null")
	luci.sys.exec("uci set amlogic.config.amlogic_write_bootloader=" .. amlogic_write_bootloader .. " 2>/dev/null")
	luci.sys.exec("uci commit amlogic 2>/dev/null")
	http.redirect(DISP.build_url("admin", "system", "amlogic", "config"))
	--self.description = "amlogic_firmware_repo: " .. amlogic_firmware_repo
end


return b

