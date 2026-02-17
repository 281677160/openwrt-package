# Copyright (C) 2024-2026 Zag <ntbowen2001@gmail.com>
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-qfirehose
PKG_VERSION:=2.1.0
PKG_RELEASE:=1
PKG_MAINTAINER:=Zag <ntbowen2001@gmail.com>
PKG_LICENSE:=GPLv3
PKG_LICENSE_FILES:=LICENSE

LUCI_TITLE:=LuCI support for QFirehose
LUCI_DESCRIPTION:=Web interface for QFirehose (v1.4.17), a tool for flashing Qualcomm firmware on OpenWrt
LUCI_DEPENDS:=+luci-base +cgi-io +qfirehose +socat
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
