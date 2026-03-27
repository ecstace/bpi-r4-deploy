#!/bin/bash
set -euo pipefail

rm -rf openwrt
rm -rf mtk-openwrt-feeds

git clone --branch openwrt-25.12 https://github.com/openwrt/openwrt.git openwrt
if [ -n "$OPENWRT_COMMIT" ] && [ "$OPENWRT_COMMIT" != "latest" ]; then
    cd openwrt; git checkout "$OPENWRT_COMMIT"; cd -;
else
    cd openwrt; git checkout f505120278fdb752586853f4df7482150d0add3b; cd -;  #ipq40xx: fix art partition name WHW03 V1
fi

git clone --branch master https://git01.mediatek.com/openwrt/feeds/mtk-openwrt-feeds
if [ -n "$MTK_COMMIT" ] && [ "$MTK_COMMIT" != "latest" ]; then
    cd mtk-openwrt-feeds; git checkout "$MTK_COMMIT"; cd -;
else
    cd mtk-openwrt-feeds; git checkout 07ef2962013b19a4a1e9f8c34a21c1e90be691ce; cd -;  #[MAC80211][WiFi6/7/8][app][Fix iwpriv/ated script]
fi

\cp -r my_files/999-sfp-10-additional-quirks.patch mtk-openwrt-feeds/25.12/files/target/linux/mediatek/patches-6.12
\cp -r my_files/100-wifi-mt76-mt7996-Use-tx_power-from-default-fw-if-EEP.patch mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/25.12/files/package/kernel/mt76/patches

cd openwrt
bash ../mtk-openwrt-feeds/autobuild/unified/autobuild.sh filogic-mac80211-mt798x_rfb-wifi7_nic prepare

\cp -r ../my_files/450-w-nand-mmc-add-bpi-r4.patch package/boot/uboot-mediatek/patches/450-add-bpi-r4.patch
\cp -r ../my_files/w-nand-mmc-filogic.mk target/linux/mediatek/image/filogic.mk

\cp -r ../my_files/sms-tool/ feeds/packages/utils/sms-tool
\cp -r ../my_files/modemdata-main/ feeds/packages/utils/modemdata
\cp -r ../my_files/luci-app-modemdata-main/luci-app-modemdata/ feeds/luci/applications
\cp -r ../my_files/luci-app-lite-watchdog/ feeds/luci/applications
\cp -r ../my_files/luci-app-sms-tool-js-main/luci-app-sms-tool-js/ feeds/luci/applications

./scripts/feeds update -a
./scripts/feeds install -a

\cp -r ../my_files/qmi.sh package/network/utils/uqmi/files/lib/netifd/proto/
chmod -R 755 package/network/utils/uqmi/files/lib/netifd/proto
chmod -R 755 feeds/luci/applications/luci-app-modemdata/root
chmod -R 755 feeds/luci/applications/luci-app-sms-tool-js/root
chmod -R 755 feeds/packages/utils/modemdata/files/usr/share

\cp -r ../configs/config.hnat.la .config
make defconfig

bash ../mtk-openwrt-feeds/autobuild/unified/autobuild.sh filogic-mac80211-mt798x_rfb-wifi7_nic build