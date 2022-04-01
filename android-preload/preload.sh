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

. "${MYDIR}/config"
[ -f "${MYDIR}/override" ] && . "${MYDIR}/override"

#adb push "$(find_latest "${ASSETS_DIR}" 'Google_Play_Store-*.apk')" /data/adb/Phonesky.apk
magisk_module_install_system "${MAGISK_MODULES[@]}"
for i in "${APKS[@]}"; do adb install -r "${i}"; done  # xargs?

# https://sr.rikka.app , https://github.com/RikkaApps/StorageRedirect-assets
if [ "$(adb shell getprop ro.build.version.sdk)" -ge 23 ]; then
  adb install -r -i 'com.android.vending' "$(find_latest "${ASSETS_DIR}" "storage-isolation-v*-$(adb shell getprop ro.product.cpu.abi).apk")"
  read -p "Launch Storage Isolation service from related app, now…"
  [ -z "${RIRU}" ] && magisk_module_install_system "$(find_latest "${ASSETS_DIR}" 'storage-isolation-zygisk-v*-release.zip')" || magisk_module_install_system "$(find_latest "${ASSETS_DIR}" 'storage-isolation-riru-v*-release.zip')"
fi

if [ "${MICROG:-1}" -eq 1 ]; then
  #adb shell su -c pm grant com.android.vending android.permission.FAKE_PACKAGE_SIGNATURE
  adb shell su -c npem
  echo "Be sure to enable the FakeGApps Xposed module for GMS services and any app using GSF."
fi

preload_post_hook

#adb_reboot system
echo 'This would be a good time to enable Zygisk and restart the device as many times as necessary for Magisk and Xposed modules to work.'
