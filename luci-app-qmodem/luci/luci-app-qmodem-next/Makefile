# Copyright (C) 2024 Tom <fjrcn@outlook.com>
# This is free software, licensed under the GNU General Public License v3.

include $(TOPDIR)/rules.mk

# Include unified version
include ../../version.mk

PKG_NAME:=luci-app-qmodem-next
PKGARCH:=all
PKG_RELEASE:=2
PKG_MAINTAINER:=Tom <fjrcn@outlook.com>
PKG_LICENSE:=GPLv3
PKG_DEPENDS:=+qmodem +qmodem-smsd +sms-forwarder-next
PKG_RECOMMENDS:=+luci-base
PKG_VERSION:=$(QMODEM_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=luci
  CATEGORY:=LuCI
  TITLE:=LuCI Modern UI for QModem
  DEPENDS:=$(PKG_DEPENDS)
  RECOMMENDS:=$(PKG_RECOMMENDS)
  PKGARCH:=all
endef

define Package/$(PKG_NAME)/description
  LuCI modern (JavaScript) interface for QModem.
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(CP) ./root/* $(1)/
	$(INSTALL_DIR) $(1)/www
	$(CP) ./htdocs/* $(1)/www/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
