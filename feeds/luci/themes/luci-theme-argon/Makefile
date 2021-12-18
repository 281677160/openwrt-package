#
# Copyright (C) 2008-2019 Jerrykuku
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-theme-argon-18.06
PKG_VERSION:=1.7.2
PKG_RELEASE:=20211217

PKG_MAINTAINER:=jerrykuku <jerrykuku@qq.com>

LUCI_TITLE:=Argon Theme
LUCI_PKGARCH:=all
LUCI_DEPENDS:=

include $(TOPDIR)/feeds/luci/luci.mk

define Package/$(PKG_NAME)/postinst
#!/bin/sh
sed -i ":a;$!N;s/tmpl.render.*sysauth_template.*return/local scope = { duser = default_user, fuser = user }\nlocal ok, res = luci.util.copcall\(luci.template.render_string, [[<% include\(\"themes\/\" .. theme .. \"\/sysauth\"\) %>]], scope\)\nif ok then\nreturn res\nend\nreturn luci.template.render\(\"sysauth\", scope\)/;ba" /usr/lib/lua/luci/dispatcher.lua
sed -i ":a;$!N;s/t.render.*sysauth_template.*return/local scope = { duser = h, fuser = a }\nlocal ok, res = luci.util.copcall\(luci.template.render_string, [[<% include\(\"themes\/\" .. theme .. \"\/sysauth\"\) %>]], scope\)\nif ok then\nreturn res\nend\nreturn luci.template.render\(\"sysauth\", scope\)/;ba" /usr/lib/lua/luci/dispatcher.lua
[ -f /usr/lib/lua/luci/view/themes/argon/out_header_login.htm ] && mv -f /usr/lib/lua/luci/view/themes/argon/out_header_login.htm /usr/lib/lua/luci/view/header_login.htm
rm -Rf /var/luci-modulecache
rm -Rf /var/luci-indexcache
exit 0
endef

# call BuildPackage - OpenWrt buildroot signature
