#!/bin/bash
# 此脚本在Imagebuilder 根目录运行
source shell/custom-packages.sh
echo "第三方软件包: $CUSTOM_PACKAGES"
LOGFILE="/tmp/uci-defaults-log.txt"
echo "Starting 99-custom.sh at $(date)" >> $LOGFILE
echo "Include Docker: $INCLUDE_DOCKER"

if [ -z "$CUSTOM_PACKAGES" ]; then
  echo "⚪️ 未选择 任何第三方软件包"
else
  # ============= 同步第三方插件库==============
  # 同步第三方软件仓库run/ipk
  echo "🔄 正在同步第三方软件仓库 Cloning run file repo..."
  git clone --depth=1 https://github.com/wukongdaily/store.git /tmp/store-run-repo

  # 拷贝 run/x86 下所有 run 文件和ipk文件 到 extra-packages 目录
  mkdir -p extra-packages
  cp -r /tmp/store-run-repo/run/x86/* extra-packages/

  echo "✅ Run files copied to extra-packages:"
  ls -lh extra-packages/*.run
  # 解压并拷贝ipk到packages目录
  sh shell/prepare-packages.sh
  ls -lah packages/
fi

# 输出调试信息
echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始构建固件..."

# ============= iStoreOS仓库内的插件==============
# 定义所需安装的包列表 下列插件你都可以自行删减
PACKAGES="base-files block-mount ca-bundle dnsmasq-full dropbear fdisk firewall4 fstools \
grub2-bios-setup i915-firmware-dmc kmod-8139cp kmod-8139too kmod-button-hotplug kmod-e1000e \
kmod-fs-f2fs kmod-i40e kmod-igb kmod-igbvf kmod-igc kmod-ixgbe kmod-ixgbevf \
kmod-nf-nathelper kmod-nf-nathelper-extra kmod-nft-offload kmod-pcnet32 kmod-r8101 \
kmod-r8125 kmod-r8126 kmod-r8168 kmod-tulip kmod-usb-hid kmod-usb-net \
kmod-usb-net-asix kmod-usb-net-asix-ax88179 kmod-usb-net-rtl8150 kmod-vmxnet3 \
libc libgcc libustream-openssl logd luci-app-package-manager luci-compat \
luci-lib-base luci-lib-ipkg luci-light mkf2fs mtd netifd nftables odhcp6c \
odhcpd-ipv6only opkg partx-utils ppp ppp-mod-pppoe procd-ujail uci uclient-fetch \
urandom-seed urngd kmod-amazon-ena kmod-amd-xgbe kmod-bnx2 kmod-e1000 kmod-dwmac-intel \
kmod-forcedeth kmod-fs-vfat kmod-tg3 kmod-drm-i915 -libustream-mbedtls"

PACKAGES="$PACKAGES \
luci-i18n-package-manager-zh-cn \
luci-i18n-argon-zh-cn \
luci-i18n-argon-config-zh-cn \
luci-i18n-filetransfer-zh-cn \
luci-i18n-quickstart-zh-cn \
luci-i18n-base-zh-cn \
luci-i18n-firewall-zh-cn \
luci-i18n-ttyd-zh-cn \
luci-i18n-cifs-mount-zh-cn \
luci-i18n-unishare-zh-cn \
luci-theme-argon \
luci-app-argon-config \
luci-app-filetransfer \
openssh-sftp-server \
luci-app-ttyd \
luci-app-cifs-mount"

# custom-packages.sh =======
# 合并iStoreOS仓库以外的第三方插件
PACKAGES="$PACKAGES $CUSTOM_PACKAGES"


# 判断是否需要编译 Docker 插件
if [ "$INCLUDE_DOCKER" = "yes" ]; then
    PACKAGES="$PACKAGES luci-i18n-dockerman-zh-cn"
    echo "Adding package: luci-i18n-dockerman-zh-cn"
else
    PACKAGES="$PACKAGES -luci-i18n-dockerman-zh-cn"
fi

# 若构建openclash 则添加内核
if echo "$PACKAGES" | grep -q "luci-app-openclash"; then
    echo "✅ 已选择 luci-app-openclash，添加 openclash core"
    mkdir -p files/etc/openclash/core
    # Download clash_meta
    META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-amd64.tar.gz"
    wget -qO- $META_URL | tar xOvz > files/etc/openclash/core/clash_meta
    chmod +x files/etc/openclash/core/clash_meta
    # Download GeoIP and GeoSite
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat -O files/etc/openclash/GeoIP.dat
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat -O files/etc/openclash/GeoSite.dat
else
    echo "⚪️ 未选择 luci-app-openclash"
fi

# 构建镜像
echo "开始构建......打印所有包名===="
echo "$PACKAGES"

make image PROFILE="generic" PACKAGES="$PACKAGES" FILES="files"

if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Build failed!"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - 构建成功."