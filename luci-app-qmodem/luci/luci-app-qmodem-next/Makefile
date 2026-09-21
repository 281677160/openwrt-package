# Copyright (C) 2024 Tom <fjrcn@outlook.com>
# This is free software, licensed under the GNU General Public License v3.

include $(TOPDIR)/rules.mk

# Include unified version
include ../../version.mk

LUCI_TITLE:=LuCI Modern UI for QModem
LUCI_DESCRIPTION:=LuCI modern (JavaScript) interface for QModem.
LUCI_DEPENDS:=+qmodem +qmodem-smsd +sms-forwarder-next +luci-base
LUCI_PKGARCH:=all
LUCI_MAINTAINER:=Tom <fjrcn@outlook.com>

PKG_VERSION:=$(QMODEM_VERSION)
PKG_RELEASE:=4
PKG_LICENSE:=GPLv3
PKG_PROVIDES:=qmodem-luci-ui

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
