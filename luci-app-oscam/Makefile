include $(TOPDIR)/rules.mk


PKG_NAME:=oscam
PKG_REV:=f118573
PKG_VERSION:=nx111-svn-1.20-11678-$(PKG_REV)
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=aafda4bca3c347698ef1dc32f7ebeff76378d55a
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_URL:=https://github.com/nx111/oscam.git
PKG_SOURCE:=$(PKG_SOURCE_SUBDIR).tar.bz2
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_MAINTAINER:=OSCam developers <unknown>
PKG_LICENSE:=GPL-3.0
PKG_LICENSE_FILES:=COPYING

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

PKG_BUILD_PARALLEL:=1
PKG_USE_MIPS16:=0

PKG_BUILD_DEPENDS:=+libopenssl +libusb-1.0 +pcsc-lite

include $(INCLUDE_DIR)/package.mk

define Package/oscam
  SECTION:=utils
  CATEGORY:=Utilities
  DEPENDS:=+libopenssl +libusb-1.0 +kmod-usb-serial-ftdi +libpcsclite
  TITLE:=OSCam is an Open Source Conditional Access Module software
  URL:=http://www.streamboard.tv/oscam/
  MAINTAINER:=OSCam developers <WF>
endef

define Package/oscam/description
  OSCam is an Open Source Conditional Access Module software
endef

MAKE_FLAGS += \
	CROSS=$(TOOLCHAIN_DIR)/bin/$(TARGET_CROSS) \
	CROSS_DIR=$(TOOLCHAIN_DIR)/bin/ \
	$(TARGET_CONFIGURE_OPTS) \
	CFLAGS="$(TARGET_CFLAGS) $(FPIC) $(TARGET_CPPFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)" \
	OSCAM_BIN=Distribution/oscam \
	SVN_REV=$(PKG_REV) \
	CONF_DIR=/etc/oscam \
	USE_LIBCRYPTO=1 \
	USE_LIBUSB=1 \
	USE_PCSC=1 \
	USE_SSL=1

define Package/oscam/conffiles
/etc/oscam/oscam.conf
/etc/oscam/oscam.user
/etc/oscam/oscam.server
/etc/oscam/oscam.srvid
endef

define Package/oscam/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/oscam.init $(1)/etc/init.d/oscam

	$(INSTALL_DIR) $(1)/etc/rc.d
	$(INSTALL_BIN) ./files/S99oscam $(1)/etc/rc.d/

	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/Distribution/oscam $(1)/usr/bin/oscam

	$(INSTALL_DIR) $(1)/etc/oscam
#	$(INSTALL_BIN) $(PKG_BUILD_DIR)/Distribution/doc/example/* $(1)/etc/oscam/
	$(INSTALL_BIN) ./files/oscam/* $(1)/etc/oscam/

endef

define Package/$(PKG_NAME)/prerm
	#!/bin/sh
	# if run within buildroot exit
	[ -n "$${IPKG_INSTROOT}" ] && exit 0

	# stop running scripts
	/etc/init.d/oscam disable
	/etc/init.d/oscam stop

	exit 0
endef

$(eval $(call BuildPackage,oscam))

