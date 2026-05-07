# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2021 ImmortalWrt.org

include $(TOPDIR)/rules.mk

PKG_NAME:=tuic-client
PKG_VERSION:=1.8.1
PKG_RELEASE:=1

PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=Tianling Shen <cnsztl@immortalwrt.org>

include $(INCLUDE_DIR)/package.mk

ifeq ($(ARCH),aarch64)
	TUIC_ARCH:=tuic-client-aarch64-linux-musl
	PKG_HASH:=68df41cff74df766f313fbef1f624825e5e8f60b9a40bdb1fb017c232db93bf3
else ifeq ($(ARCH),arm)
# Referred to golang/golang-values.mk
	ARM_CPU_FEATURES:=$(word 2,$(subst +,$(space),$(call qstrip,$(CONFIG_CPU_TYPE))))
	ifeq ($(ARM_CPU_FEATURES),)
		TUIC_ARCH:=tuic-client-armv7-linux-musl
		PKG_HASH:=19c9af5c7115f4526268a9d86446ce0ceef2ee80ad5ad6aed84ed59540c6262c
	else
		TUIC_ARCH:=tuic-client-armv7-linux-muslhf
		PKG_HASH:=7a1410197ab5804c9f1ddd1a3ff7f4765e51f30d626ae99e04509ebf69b3979c
	endif
else ifeq ($(ARCH),i386)
	TUIC_ARCH:=tuic-client-i686-linux-musl
	PKG_HASH:=fd0992d8a799cf897057d2c5fc3354a7f0f366cc35b3f7508736e81758289883
else ifeq ($(ARCH),x86_64)
	TUIC_ARCH:=tuic-client-x86_64-linux-musl
	PKG_HASH:=542d50e33f9b470a564b9a16f4c321c7c955af81703e2e05bee4fc2869cebffe
# Set the default value to make OpenWrt Package Checker happy
else
  PKG_SOURCE:=dummy
  PKG_HASH:=dummy
endif

define Download/tuic-client
	URL:=https://github.com/Itsusinn/tuic/releases/download/v$(PKG_VERSION)/
	URL_FILE:=$(TUIC_ARCH)
	FILE:=$(TUIC_ARCH)-$(PKG_VERSION)
	HASH:=$(PKG_HASH)
endef

$(eval $(call Download,tuic-client))

define Package/tuic-client
	SECTION:=net
	CATEGORY:=Network
	SUBMENU:=Web Servers/Proxies
	TITLE:=Delicately-TUICed 0-RTT proxy protocol
	URL:=https://github.com/Itsusinn/tuic
	DEPENDS:=@USE_MUSL @(aarch64||arm_v7||i386||x86_64) @!(TARGET_x86_geode||TARGET_x86_legacy)
endef

define Build/Compile
endef

define Package/tuic-client/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(DL_DIR)/$(TUIC_ARCH)-$(PKG_VERSION) $(1)/usr/bin/tuic-client
endef

$(eval $(call BuildPackage,tuic-client))
