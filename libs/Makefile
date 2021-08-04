826a560b-1d11-412d-b124-783a5ddf347f

https://api.telegram.org/bot1494307178:AAHaUScEMeT0EVsjF4lwrCH6ykQjOCRuu2E/getUpdates
find . -name 'python3-cached-property'
liblua5.3
grep "python3-pynacl" -rl ./

x86_generic
git clone -b barrier_breaker https://github.com/lunatickochiya/barrier_breaker open

git clone -b lede-17.01 https://github.com/coolsnowwolf/openwrt
git clone --depth 1 -b lede-17.01 https://github.com/281677160/openwrt-package

cp -Rf openwrt open

git clone https://github.com/small-5/luci-app-adblock-plus package/luci-app-adblock-plus

sudo apt-get -y install build-essential asciidoc binutils bzip2 gawk gettext git libncurses5-dev libz-dev patch python3 python2.7 unzip zlib1g-dev lib32gcc1 libc6-dev-i386 subversion flex uglifyjs git-core gcc-multilib p7zip p7zip-full msmtp libssl-dev texinfo libglib2.0-dev xmlto qemu-utils upx libelf-dev autoconf automake libtool autopoint device-tree-compiler g++-multilib antlr3 gperf wget curl rename libpcap0.8-dev swig rsync

setup-alpine
https://jy.ahzcxx.cn/transfer/preparesend
./transfer cow --block 2621440 -s -p 64 --no-progress openwrt/build/Lede_source 2>&1 | tee cowtransfer.log

./transfer cow --block 2621440 -s --no-progress openwrt/build/Lede_source
./transfer wen openwrt/build/Lede_source 2>&1 | tee cowtransfer.log

./transfer wen -s -p 16 --no-progress gujian 2>&1 | tee wetransfer.log

mv gujian/07.27-lede-x86-64-generic-squashfs-combined-efi.img.gz gujian/openwrt-x86-64-generic-squashfs-combined-efi.img.gz

sed -i "s/Download Link/奶牛快传/g" cowtransfer.log

sudo apt-get install qemu
qemu-img convert -f raw -O vmdk op.img op.vmdk

cp /home/dan/openwrt/bin/targets/x86/64/openwrt-sdk-x86-64_gcc-7.5.0_musl.Linux-x86_64.tar.xz ./

tar xvJf  openwrt-sdk-x86-64_gcc-7.5.0_musl.Linux-x86_64.tar.xz

cp -Rf /home/dan/openwrt /home/dan/open

cp openwrt/bin/targets/x86/64/openwrt-x86-64-generic-rootfs.tar.gz vlede/vlede.tar.gz

mv openwrt-sdk-x86-64_gcc-7.5.0_musl.Linux-x86_64 openwrt-sdk

svn co https://github.com/1715173329/immortalwrt/branches/1806-k54-r2s-oc/target/linux/rockchip target/linux/rockchip

git clone https://github.com/xiaorouji/openwrt-passwall package/openwrt-passwall
svn co https://github.com/coolsnowwolf/lede/trunk/package/lean/redsocks2 package/redsocks2

make package/luci-app-ssr-plus/compile V=s

sed -i "s/'zh_cn'/'auto'/g" /etc/config/luci
git clone https://github.com/ophub/amlogic-s9xxx-openwrt
mv amlogic-s9xxx-openwrt/{amlogic-s9xxx,make} $GITHUB_WORKSPACE

sudo ./make -d -b s905x3_s905x2_s905x_s905d_s922x_s912 -k 5.13.5_5.4.135

curl -fsSL https://raw.githubusercontent.com/P3TERX/dotfiles/master/.zshrc >> ~/.zshrc

    - name: Prepare build docker image dir
      run: |
        git clone --depth 1 https://github.com/crazygit/openwrt-x86-64.git -b master dockerfile_dir
        cp openwrt/bin/targets/x86/64/openwrt-x86-64-generic-rootfs.tar.gz dockerfile_dir/openwrt.tar.gz

    - name: Publish to Registry
      uses: elgohr/Publish-Docker-Github-Action@main
      env:
        FIRMWARE: openwrt.tar.gz
      with:
        workdir: dockerfile_dir
        name: ${{ env.REPOSITORY }}
        username: ${{ secrets.DOCKER_USERNAME }}
        password: ${{ secrets.DOCKER_TOKEN }}
        buildargs: FIRMWARE
        snapshot: true
