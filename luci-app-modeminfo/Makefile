include $(TOPDIR)/rules.mk

LUCI_TITLE:=Information dashboard for 3G/LTE dongle
LUCI_DEPENDS:=+comgt
PKG_LICENSE:=GPLv3

define Package/luci-app-modeminfo/conffiles
	/etc/config/modeminfo
endef

define Package/luci-app-modeminfo/postrm
	rm -f /tmp/luci-indexcache
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
