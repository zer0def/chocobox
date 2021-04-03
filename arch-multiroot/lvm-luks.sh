#!/bin/bash -ex

# shellcheck disable=SC1090
. "$(dirname "$(readlink -f "${0}")")/config"
# shellcheck disable=SC1090
. "$(dirname "$(readlink -f "${0}")")/common"

LV=()
MOUNT=()

cleanup(){
  set +e
  umount -R "${MOUNTPOINT}"/*
  # shellcheck disable=SC2004
  for i in $(seq 0 $((${ROOT_COUNT}-1))); do
    cryptsetup close "${MOUNT[${i}]}"
    lvchange -an "${VG_NAME}/${LV[${i}]}"
  done
  vgchange -an "${VG_NAME}"
  cleanup_common
}
trap cleanup INT QUIT TERM EXIT

#prep_bios_uefi
prep_uefi_only

pvcreate -ff "${DETACHED_LUKS[@]/#/\/dev\/mapper\/}"
vgcreate "${VG_NAME}" "${DETACHED_LUKS[@]/#/\/dev\/mapper\/}"

# shellcheck disable=SC2004
for i in $(seq 0 $((${ROOT_COUNT}-1))); do
  LV+=("$(uuidgen)") MOUNT+=("$(uuidgen)")
  # shellcheck disable=SC2004
  lvcreate -n "${LV[${i}]}" -l "$((100/$((${ROOT_COUNT}-${i}))))%FREE" "${VG_NAME}"

  TMP_HEADER="${HEADER_TMPDIR}/${MOUNT[${i}]}"
  dd if=/dev/urandom of="${TMP_HEADER}" bs=16M count=1
  cryptsetup -h "${CRYPTO_HASH}" -c "${CRYPTO_CIPHER}" -s "${CRYPTO_KEYSIZE}" -y luksFormat --header "${TMP_HEADER}" "/dev/${VG_NAME}/${LV[${i}]}"
  cryptsetup luksOpen --header "${TMP_HEADER}" "/dev/${VG_NAME}/${LV[${i}]}" "${MOUNT[${i}]}"
  mkfs.ext4 -m 0 -i 4096 -b 4096 -E lazy_itable_init=0,lazy_journal_init=0 "/dev/mapper/${MOUNT[${i}]}"

  mkdir -p "${MOUNTPOINT}/${MOUNT[${i}]}"
  mount "/dev/mapper/${MOUNT[${i}]}" "${MOUNTPOINT}/${MOUNT[${i}]}"
done

# shellcheck disable=SC2004
for i in $(seq 0 $((${ROOT_COUNT}-1))); do
  # bootstrap the template
  if [ "${i}" -eq 0 ]; then
    bootstrap_arch "${MOUNTPOINT}/${MOUNT[${i}]}"
    arch-chroot "${MOUNTPOINT}/${MOUNT[${i}]}" pacman --noconfirm -Sy lvm2
    install_pkgbuild "${MOUNTPOINT}/${MOUNT[${i}]}" mkinitcpio-encrypt-detached-header

    cp "${MOUNTPOINT}/${MOUNT[${i}]}/etc/mkinitcpio.conf" "${MOUNTPOINT}/${MOUNT[${i}]}/etc/mkinitcpio.conf.pacsave"
    cat <<EOF > "${MOUNTPOINT}/${MOUNT[${i}]}/etc/mkinitcpio.conf"
MODULES=(ext4)
HOOKS=(base keyboard udev autodetect modconf block mdadm_udev multiencrypt lvm2 encrypt-dh filesystems fsck)
EOF
  else
    rsync -xaSPAX -zz "${MOUNTPOINT}/${MOUNT[0]}/" "${MOUNTPOINT}/${MOUNT[${i}]}"
  fi

  genfstab -U -p "${MOUNTPOINT}/${MOUNT[${i}]}" | sed -e '/^[[:space:]]*$/d' -e '/\/dev\/zram/d' > "${MOUNTPOINT}/${MOUNT[${i}]}/etc/fstab"
  echo "GRUB_CMDLINE_LINUX_DEFAULT+=' cryptdevice=/dev/${VG_NAME}/${LV[${i}]}:${MOUNT[${i}]} cryptheader=/dev/mapper/${BOOTS[0]}:ext4:/headers/${MOUNT[${i}]}'" >>"${MOUNTPOINT}/${MOUNT[${i}]}/etc/default/grub"

  if [ "${i}" -eq 0 ]; then
    finish_arch "${MOUNTPOINT}/${MOUNT[${i}]}"
    umount -R "${MOUNTPOINT}/${MOUNT[${i}]}/boot"
  else
    #arch-chroot "${MOUNTPOINT}/${MOUNT[${i}]}" /bin/sh -c 'grub-mkconfig -o /boot/grub/grub.cfg'
    :
  fi
done
