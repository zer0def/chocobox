#!/bin/bash -x
#ANDROID_SERIAL=
#MYDIR="$(dirname "$(readlink -f "${0}")")"
MYDIR="$(readlink -f "$(dirname "${0}")")"
ASSETS_DIR="${ASSETS_DIR:-${MYDIR}}"

. "${MYDIR}/common"
#adb wait-for-usb-device; until adb install -r "${MAGISK_MAN_APK}"; do sleep 2; done
#magisk_module_install_system "$(find_latest "${ASSETS_DIR}" 'Busybox_for_Android_NDK-*.zip')"
#adb_reboot system

adb wait-for-usb-device; until adb install -r "${MAGISK_MAN_APK}"; do sleep 2; done  # improvised spinlock
until adb shell su -c echo; do sleep 2; done

if [ "${MICROG:-1}" -eq 1 ]; then
  #adb shell su -c pm grant com.android.vending android.permission.FAKE_PACKAGE_SIGNATURE
  adb shell su -c npem
fi

. "${MYDIR}/config"
[ -f "${MYDIR}/override" ] && . "${MYDIR}/override"

MOMOHIDER_COMPONENTS=(
  #isolated setns
  app_zygote_magic initrc
)

preload_ota_cfg
cat <<EOF | adb shell su
# Riru app: https://github.com/RikkaApps/Riru
mkdir -p /data/adb/modules/riru-core
touch /data/adb/modules/riru-core/allow_install_app

# MomoHider config: https://github.com/canyie/Riru-MomoHider
mkdir -p /data/adb/momohider
touch ${MOMOHIDER_COMPONENTS[@]/#/\/data\/adb\/momohider\/}
EOF
magisk_module_install_system "${MAGISK_MODULES[@]}"
for i in "${APKS[@]}"; do adb install -r "${i}"; done  # xargs?

# https://sr.rikka.app , https://github.com/RikkaApps/StorageRedirect-assets
if [ "$(adb shell getprop ro.build.version.sdk)" -ge 23 ]; then
  adb install -r -i 'com.android.vending' "$(find_latest "${ASSETS_DIR}" "storage-isolation-v*-$(adb shell getprop ro.product.cpu.abi).apk")"
  read -p "Launch Storage Isolation service from related app, now…"
  magisk_module_install_system "$(find_latest "${ASSETS_DIR}" 'riru-storage-isolation-v*-release.zip')"
fi

#adb_reboot system
echo 'This would be a good time to restart the device.'
