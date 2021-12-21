#!/bin/bash -ex
#ANDROID_SERIAL=
#MYDIR="$(dirname "$(readlink -f "${0}")")"
MYDIR="$(readlink -f "$(dirname "${0}")")"
ASSETS_DIR="${MYDIR}"
DEVICE="${DEVICE:-i9082-baffin}"
OTA_METHOD="${OTA_METHOD:-push}"
. "${MYDIR}/common"
. "${MYDIR}/flashcfgs/${DEVICE}"
#MAGISK_BOOT_PATCH=0

adb kill-server
# get whatever decryption prompt out of the way
#data_decryption_attempt "$(uuidgen)"

adb wait-for-usb-recovery  # if you're stuck here, try starting and cancelling `adb sideload`
[ -n "${DIRTY_FLASH}" ] || SYSTEM_WIPE="/system"
for i in ${SYSTEM_WIPE:+/system} /cache dalvik; do
  adb shell twrp wipe "${i}" ||:
  adb wait-for-usb-recovery
  sleep 2
done
#$(getprop twrp.mount_to_decrypt) → 0 ??
if [ -z "${DIRTY_FLASH}" ]; then
  [ -n "$(adb shell getprop ro.crypto.fs_crypto_blkdev)" ] || wipe_data
  [ -n "${WIPE_DATA}" ] && [ -z "${WIPE_DATA_FASTBOOT}" ] && wipe_data ||:
fi

if [ -n "${AB_DEV}" ] || [ -n "${HUAWEI}" ]; then
  if [ -n "${HUAWEI}" ]; then
    huawei_system_flash
    #adb reboot bootloader; adb wait-for-usb-bootloader
    #sudo fastboot flash system "${SYSTEM_IMG}"
    #read -p "Reboot back into recovery now…"
  else
    echo "Current slot is:"
adb shell sh <<'EOF'
grep -oE 'androidboot.slot(_suffix)?=[^ ]+' /proc/cmdline | awk -F= '{print $NF}'
EOF
    "ota_pkg_${OTA_METHOD:-push}" "${ANDROID_ZIPS[0]}"
    read -p "Switch the slot now…"
    unset ANDROID_ZIPS[0]
  fi
  #unset ANDROID_ZIPS[0]
  reboot_and_wait_for_recovery
fi

adb wait-for-usb-recovery
"ota_pkg_${OTA_METHOD:-push}" "${ANDROID_ZIPS[@]}"
#preload_ota_cfg
#"ota_pkg_${OTA_METHOD:-push}" "${MAGISK_ZIP}"
[ -z "${DEBUG}" ] || inject_boot_logcat

magisk_boot_patch  # dirty flash adjustment?

#"ota_pkg_${OTA_METHOD:-push}" "${MAGISK_ZIP}"
#adb reboot system
[ -z "${ENCRYPT}" ] || setup_encryption
[ -z "${DEBUG}" ] || /bin/bash -c "adb logcat | tee '${DEBUG}'"
[ -n "${DIRTY_FLASH}" ] || [ -z "${PRELOAD}" ] || "${MYDIR}/preload.sh"
