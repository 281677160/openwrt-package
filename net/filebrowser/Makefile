#
# Copyright (C) 2014-2018 OpenWrt-dist
# Copyright (C) 2019 [CTCGFW] Project OpenWRT
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=filebrowser
PKG_VERSION:=2.3.3
PKG_RELEASE:=1

PKG_LICENSE:=GPLv3
PKG_MAINTAINER:=[CTCGFW] Project OpenWRT

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=utils
	CATEGORY:=Utilities
	TITLE:=LuCI Support for FileBrowser.
	URL:=https://github.com/filebrowser/filebrowser
endef

define Package/$(PKG_NAME)/description
LuCI Support for FileBrowser.
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/bin
ifeq ($(ARCH),i386)
	$(INSTALL_BIN) ./files/i386 $(1)/usr/bin/filebrowser
endif
ifeq ($(ARCH),i386)
	$(INSTALL_BIN) ./files/dict.txt $(1)/usr/bin/dict.txt
endif
ifeq ($(ARCH),x86_64)
	$(INSTALL_BIN) ./files/x86_64 $(1)/usr/bin/filebrowser
endif
ifeq ($(ARCH),x86_64)
	$(INSTALL_BIN) ./files/dict.txt $(1)/usr/bin/dict.txt
endif
ifeq ($(ARCH),aarch64)
	$(INSTALL_BIN) ./files/arm64 $(1)/usr/bin/filebrowser
endif
ifeq ($(ARCH),aarch64)
	$(INSTALL_BIN) ./files/dict.txt $(1)/usr/bin/dict.txt
endif
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
