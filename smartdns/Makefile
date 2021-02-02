#
# Copyright (c) 2018-2020 Nick Peng (pymumu@gmail.com)
# This is free software, licensed under the GNU General Public License v3.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=smartdns
PKG_VERSION:=9.2020.10.15
PKG_RELEASE:=2235

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://www.github.com/pymumu/smartdns.git
PKG_SOURCE_VERSION:=42b3e98b2a3ca90ea548f8cb5ed19a3da6011b74
# PKG_MIRROR_HASH:=d5affc45a533e38ee04f3ce47b441aecf316cb9cb68ff410eede67090ec0fcc7

PKG_MAINTAINER:=Nick Peng <pymumu@gmail.com>
PKG_LICENSE:=GPL-3.0-or-later
PKG_LICENSE_FILES:=LICENSE

PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

MAKE_VARS += VER=$(PKG_VERSION) 
MAKE_PATH:=src

define Package/smartdns
  SECTION:=net
  CATEGORY:=Network
  TITLE:=smartdns server
  DEPENDS:=+libc +libpthread +libopenssl
  URL:=https://www.github.com/pymumu/smartdns/
endef

define Package/smartdns/description
SmartDNS is a local DNS server which accepts DNS query requests from local network clients,
gets DNS query results from multiple upstream DNS servers concurrently, and returns the fastest IP to clients.
Unlike dnsmasq's all-servers, smartdns returns the fastest IP. 
endef

define Package/smartdns/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/smartdns $(1)/usr/sbin/smartdns
endef

$(eval $(call BuildPackage,smartdns))
