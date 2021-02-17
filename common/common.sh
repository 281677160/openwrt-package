Diy_all() {
echo "all"
}

#####

Diy_lede() {
echo "LEDE源码自定义1"
rm -rf package/lean/{luci-app-netdata,luci-theme-argon,k3screenctrl}

git clone -b $REPO_BRANCH --single-branch https://github.com/281677160/openwrt-package package/danshui
svn co https://github.com/281677160/openwrt-package/branches/usb/AutoUpdate package/base-files/files/bin
chmod +x package/base-files/files/bin/* ./

git clone https://github.com/fw876/helloworld package/danshui/luci-app-ssr-plus
git clone https://github.com/xiaorouji/openwrt-passwall package/danshui/luci-app-passwall
git clone https://github.com/jerrykuku/luci-app-vssr package/danshui/luci-app-vssr
git clone https://github.com/vernesong/OpenClash package/danshui/luci-app-openclash

git clone https://github.com/garypang13/luci-app-bypass package/luci-app-bypass
svn co https://github.com/garypang13/openwrt-packages/trunk/lua-maxminddb
find package/*/ feeds/*/ -maxdepth 2 -path "*luci-app-bypass/Makefile" | xargs -i sed -i 's/shadowsocksr-libev-ssr-redir/shadowsocksr-libev-alt/g' {}
find package/*/ feeds/*/ -maxdepth 2 -path "*luci-app-bypass/Makefile" | xargs -i sed -i 's/shadowsocksr-libev-ssr-server/shadowsocksr-libev-server/g' {}
}

#####

Diy_lienol() {
echo "LIENOL源码自定义1"
rm -rf package/lean/{luci-app-netdata,luci-theme-argon,k3screenctrl}

git clone -b $REPO_BRANCH --single-branch https://github.com/281677160/openwrt-package package/danshui
svn co https://github.com/281677160/openwrt-package/branches/usb/AutoUpdate package/base-files/files/bin
chmod +x package/base-files/files/bin/* ./

git clone https://github.com/fw876/helloworld package/luci-app-ssr-plus
git clone https://github.com/xiaorouji/openwrt-passwall package/luci-app-passwall
git clone https://github.com/jerrykuku/luci-app-vssr package/luci-app-vssr
git clone https://github.com/vernesong/OpenClash package/luci-app-openclash

git clone https://github.com/garypang13/luci-app-bypass package/luci-app-bypass
svn co https://github.com/garypang13/openwrt-packages/trunk/lua-maxminddb
find package/*/ feeds/*/ -maxdepth 2 -path "*luci-app-bypass/Makefile" | xargs -i sed -i 's/shadowsocksr-libev-ssr-redir/shadowsocksr-libev-alt/g' {}
find package/*/ feeds/*/ -maxdepth 2 -path "*luci-app-bypass/Makefile" | xargs -i sed -i 's/shadowsocksr-libev-ssr-server/shadowsocksr-libev-server/g' {}
}

#####

Diy_immortalwrt() {
echo "天灵源码自定义1"
rm -rf package/lienol/luci-app-timecontrol
rm -rf package/ctcgfw/{luci-app-argon-config,luci-theme-argonv3}

git clone -b $REPO_BRANCH --single-branch https://github.com/281677160/openwrt-package package/danshui
svn co https://github.com/281677160/openwrt-package/branches/usb/AutoUpdate package/base-files/files/bin
chmod +x package/base-files/files/bin/* ./

git clone https://github.com/garypang13/luci-app-bypass package/luci-app-bypass
svn co https://github.com/garypang13/openwrt-packages/trunk/lua-maxminddb
}

######################################################################################################


Diy_all2() {
echo "all2"
rm -rf {LICENSE,README,README.md}
rm -rf ./*/{LICENSE,README,README.md}
rm -rf ./*/*/{LICENSE,README,README.md}
git clone https://github.com/openwrt-dev/po2lmo.git
pushd po2lmo
make && sudo make install
popd
}

Diy_lede2() {
echo "LEDE源码自定义2"
curl -fsSL  https://raw.githubusercontent.com/xiaorouji/openwrt-passwall/main/v2ray-plugin/Makefile > package/lean/v2ray-plugin/Makefile
}

Diy_lienol2() {
echo "LIENOL源码自定义2"
}

Diy_immortalwrt2() {
echo "天灵源码自定义2"
}


######################################################################################################


Diy_n1() {
cd ../
svn co https://github.com/281677160/N1/trunk reform
cd openwrt
}

Diy_n1_2() {
cd ../
cp openwrt/bin/targets/armvirt/*/*.tar.gz reform/openwrt
cd reform
sudo ./gen_openwrt -d -k latest
         
devices=("phicomm-n1" "rk3328" "s9xxx" "vplus")
cd out
for x in ${devices[*]}; do
cd $x
filename=$(ls | awk -F '.img' '{print $1}')
gzip *.img
cd ../
echo "firmware_$x=$filename" >> $GITHUB_ENV
done
cd ../../
mv -f reform/out/*/*.img.gz openwrt/bin/targets/armvirt/*
}
