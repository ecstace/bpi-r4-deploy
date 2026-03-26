#!/bin/bash

rm -rf openwrt
rm -rf mtk-openwrt-feeds

git clone --branch openwrt-25.12 https://github.com/openwrt/openwrt.git openwrt
cd openwrt; git checkout f505120278fdb752586853f4df7482150d0add3b; cd -;		#ipq40xx: fix art partition name WHW03 V1

git clone --branch master https://git01.mediatek.com/openwrt/feeds/mtk-openwrt-feeds
cd mtk-openwrt-feeds; git checkout 07ef2962013b19a4a1e9f8c34a21c1e90be691ce; cd -;	#[MAC80211][WiFi6/7/8][app][Fix iwpriv/ated script]

cd openwrt
bash ../mtk-openwrt-feeds/autobuild/unified/autobuild.sh filogic prepare 

scripts/feeds uninstall crypto-eip pce tops-tool

\cp -r ../my_files/450-w-nand-mmc-add-bpi-r4.patch package/boot/uboot-mediatek/patches/450-add-bpi-r4.patch
\cp -r ../my_files/w-nand-mmc-filogic.mk target/linux/mediatek/image/filogic.mk

mkdir -p files/root/bpi-r4-install
\cp ../my_files/bpi-r4-install/snand-img.bin files/root/bpi-r4-install/
\cp ../my_files/bpi-r4-install/install-nand.sh files/root/bpi-r4-install/
#\cp ../my_files/bpi-r4-install/install-emmc.sh files/root/bpi-r4-install/
chmod +x files/root/bpi-r4-install/install-nand.sh
#chmod +x files/root/bpi-r4-install/install-emmc.sh

# Set hostname for rescue system
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-hostname << 'EOF'
uci set system.@system[0].hostname='OpenWrt-SD-rescue'
uci commit system
EOF

\cp -r ../configs/rescue.defconfig .config
make defconfig


bash ../mtk-openwrt-feeds/autobuild/unified/autobuild.sh filogic build

exit

