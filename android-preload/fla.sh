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

adb wait-for-usb-recovery
[ -n "${DIRTY_FLASH}" ] || SYSTEM_WIPE="/system"
for i in ${SYSTEM_WIPE:+/system} /cache dalvik; do
  adb shell twrp wipe "${i}" ||:
  adb wait-for-usb-recovery
  sleep 2
done
#$(getprop twrp.mount_to_decrypt) → 0 ??
if [ -z "${DIRTY_FLASH}" ]; then
  [ -n "$(adb shell getprop ro.crypto.fs_crypto_blkdev)" ] || wipe_data
  [ -z "${WIPE_DATA}" ] || wipe_data
fi

"ota_pkg_${OTA_METHOD:-push}" "${ANDROID_ZIPS[@]}"
#preload_ota_cfg
#"ota_pkg_${OTA_METHOD:-push}" "${MAGISK_ZIP}"

#adb reboot system; adb wait-for-usb-device
#[ -z "${ENCRYPT:-0}" ] || setup_encryption
#reboot_and_wait_for_recovery

magisk_boot_patch  # dirty flash adjustment?

[ -z "${DEBUG}" ] || inject_boot_logcat
#"ota_pkg_${OTA_METHOD:-push}" "${MAGISK_ZIP}"
adb reboot system
#[ -z "${ENCRYPT:-0}" ] || setup_encryption
[ -z "${DEBUG}" ] || /bin/bash -c "adb logcat | tee '${DEBUG}'"
[ -n "${DIRTY_FLASH}" ] || [ -z "${PRELOAD}" ] || "${MYDIR}/preload.sh"
