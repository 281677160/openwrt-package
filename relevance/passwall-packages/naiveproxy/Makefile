include $(TOPDIR)/rules.mk

PKG_NAME:=naiveproxy
PKG_VERSION:=147.0.7727.49
PKG_RELEASE:=1

ARCH_PREBUILT:=$(ARCH_PACKAGES)

# intel 80386 & riscv64 & cortex-a76
ifeq ($(ARCH_PREBUILT),aarch64_cortex-a76)
  ARCH_PREBUILT:=aarch64_generic
else ifeq ($(ARCH_PREBUILT),i386_pentium-mmx)
  ARCH_PREBUILT:=x86
else ifeq ($(ARCH_PREBUILT),i386_pentium4)
  ARCH_PREBUILT:=x86
else ifeq ($(ARCH_PREBUILT),mipsel_24kc_24kf)
  ARCH_PREBUILT:=mipsel_24kc
else ifeq ($(ARCH_PREBUILT),mipsel_74kc)
  ARCH_PREBUILT:=mipsel_24kc
else ifeq ($(ARCH_PREBUILT),riscv64_riscv64)
  ARCH_PREBUILT:=riscv64
endif

PKG_SOURCE:=naiveproxy-v$(PKG_VERSION)-$(PKG_RELEASE)-openwrt-$(ARCH_PREBUILT).tar.xz
PKG_SOURCE_URL:=https://github.com/klzgrad/naiveproxy/releases/download/v$(PKG_VERSION)-$(PKG_RELEASE)/

ifeq ($(ARCH_PREBUILT),aarch64_cortex-a53)
  PKG_HASH:=c2fbae18ae7c7f64fdf5f741663800bd866d5d576cd7fcd9594e064f79b6851c
else ifeq ($(ARCH_PREBUILT),aarch64_cortex-a72)
  PKG_HASH:=c942217b19864569851b350028c0ae3e3fac5768d83878174e4e8b187cd6bbf2
else ifeq ($(ARCH_PREBUILT),aarch64_generic)
  PKG_HASH:=33b424e2b7f7420798346807a02ad726b6a6c6da44b4e5d0165b6e585c93edb3
else ifeq ($(ARCH_PREBUILT),arm_arm1176jzf-s_vfp)
  PKG_HASH:=59b758c18d1016d7f2932578e20eb6208d0625584f90546aa7c563c8f7a9abb3
else ifeq ($(ARCH_PREBUILT),arm_arm926ej-s)
  PKG_HASH:=6f75829a19e595223a9701b8ad4686a9888e725b5d19fa927ae26042f92eb9a0
else ifeq ($(ARCH_PREBUILT),arm_cortex-a15_neon-vfpv4)
  PKG_HASH:=913d88f3cf4a37496533212e0738fe21e3bcdf6f3d90f0ad60a3adde53d754f0
else ifeq ($(ARCH_PREBUILT),arm_cortex-a5_vfpv4)
  PKG_HASH:=372a8b1b2afb796c5b79dd626157aa2665f5b4da8e8c490f83bda977d1fb6ca4
else ifeq ($(ARCH_PREBUILT),arm_cortex-a7)
  PKG_HASH:=48baa8f2e91b661a0abfc8e70d1f33dd3785346f47a9bf2a29e7641deb151e82
else ifeq ($(ARCH_PREBUILT),arm_cortex-a7_neon-vfpv4)
  PKG_HASH:=42f924c181f28cd7218846b132e7136153287bce72963a2bbf4c69fdbd6d5d61
else ifeq ($(ARCH_PREBUILT),arm_cortex-a7_vfpv4)
  PKG_HASH:=cb426dbda71663b920a74455f71e7a0d311cae089a54d24adc104d56dd629c78
else ifeq ($(ARCH_PREBUILT),arm_cortex-a8_vfpv3)
  PKG_HASH:=30cf5ef76428313255531efaa49061247330838a8aed6e3e9a850c700aa0461a
else ifeq ($(ARCH_PREBUILT),arm_cortex-a9)
  PKG_HASH:=bea7e95b7248e297d9695db5d63314150b2bf1a3909e140046b3040d36a2c379
else ifeq ($(ARCH_PREBUILT),arm_cortex-a9_neon)
  PKG_HASH:=0a940e25e1b9b5dacbf0d28ddf008e3447266906841a47d34f59772f0bde910a
else ifeq ($(ARCH_PREBUILT),arm_cortex-a9_vfpv3-d16)
  PKG_HASH:=87fbd18dabc1452eadf3f6fa596190e008b04af1ebc01882eecf3d30f36392dc
else ifeq ($(ARCH_PREBUILT),arm_mpcore)
  PKG_HASH:=347cc3bd2f75388e18c870c013f05b434e8d55782d4941b7ad1eb3f7ddfe1813
else ifeq ($(ARCH_PREBUILT),arm_xscale)
  PKG_HASH:=f493072e11bad79083601c37accf85943898ce930145e7991d9b034e872c47e2
else ifeq ($(ARCH_PREBUILT),mipsel_24kc)
  PKG_HASH:=53e791aa1701ebe3d04c9b991736fd0bcb22f1e8a65578821166be6438998b3e
else ifeq ($(ARCH_PREBUILT),mipsel_mips32)
  PKG_HASH:=92725dd55a8ac47dde3143043598e3b1da5da3d0364c259d1de67a915f3bd493
else ifeq ($(ARCH_PREBUILT),riscv64)
  PKG_HASH:=b921d71de172e62697374011bebcf86c9a50cda74d01bddc6b916e34c0dff6cd
else ifeq ($(ARCH_PREBUILT),x86)
  PKG_HASH:=c6c7115fdaf7cec9d0f0ea2416b4374419faffa16c00f93e2f390ece02328ebe
else ifeq ($(ARCH_PREBUILT),x86_64)
  PKG_HASH:=66f1d0924959fcbe749695a41747afc37b7162bb2ef2684d9976807c8b23112a
else
  PKG_HASH:=dummy
endif

PKG_LICENSE:=BSD 3-Clause
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=sbwml <admin@cooluc.com>

PKG_BUILD_DIR:=$(BUILD_DIR)/naiveproxy-v$(PKG_VERSION)-$(PKG_RELEASE)-openwrt-$(ARCH_PACKAGES)

include $(INCLUDE_DIR)/package.mk

define Package/naiveproxy
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Web Servers/Proxies
  TITLE:=Make a fortune quietly
  URL:=https://github.com/klzgrad/naiveproxy
  DEPENDS:=@(aarch64||arm||i386||mipsel||riscv64||x86_64) +libatomic
endef

define Package/naiveproxy/description
  NaïveProxy uses Chrome's network stack to camouflage traffic with strong
  censorship resistance and low detectability. Reusing Chrome's stack also
  ensures best practices in performance and security.
endef

define Package/naiveproxy/conffiles
/etc/config/naiveproxy
endef

define Build/Prepare
	$(TAR) --strip-components=1 -C $(PKG_BUILD_DIR) -xJf $(DL_DIR)/naiveproxy-v$(PKG_VERSION)-$(PKG_RELEASE)-openwrt-$(ARCH_PREBUILT).tar.xz
endef

define Build/Compile
endef

define Package/naiveproxy/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/naive $(1)/usr/bin/naive
	$(INSTALL_DIR) $(1)/etc/config $(1)/etc/init.d
	$(INSTALL_CONF) $(CURDIR)/files/naiveproxy.config $(1)/etc/config/naiveproxy
	$(INSTALL_BIN) $(CURDIR)/files/naiveproxy.init $(1)/etc/init.d/naiveproxy
endef

$(eval $(call BuildPackage,naiveproxy))
