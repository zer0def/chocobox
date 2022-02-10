#!/bin/bash -ex

# shellcheck disable=SC1090
. "$(dirname "$(readlink -f "${0}")")/../config"
# shellcheck disable=SC1090
. "$(dirname "$(readlink -f "${0}")")/../common"
. "$(dirname "$(readlink -f "${0}")")/common"

#prep_bios_uefi
prep_uefi_only

. "$(dirname "$(readlink -f "${0}")")/../cleanups"
trap lvm_cleanup INT QUIT TERM EXIT

. "$(dirname "$(readlink -f "${0}")")/../setups"
lvm_setup

# shellcheck disable=SC2004
for i in $(seq 0 $((${ROOT_COUNT}-1))); do
  mkdir -p "${MOUNTPOINT}/${MOUNT[${i}]}"
  mount "/dev/mapper/${MOUNT[${i}]}" "${MOUNTPOINT}/${MOUNT[${i}]}"

  if [ "${i}" -ne 0 ]; then
    rsync -xaSPAX -zz "${MOUNTPOINT}/${MOUNT[0]}/" "${MOUNTPOINT}/${MOUNT[${i}]}"
  else  # bootstrap the template
    . "$(dirname "$(readlink -f "${0}")")/../bootstraps"
    DISTRO=arch common_bootstrap "${MOUNTPOINT}/${MOUNT[${i}]}"

    arch-chroot "${MOUNTPOINT}/${MOUNT[${i}]}" pacman --noconfirm -Sy lvm2
    install_pkgbuild "${MOUNTPOINT}/${MOUNT[${i}]}" mkinitcpio-encrypt-detached-header

    cp "${MOUNTPOINT}/${MOUNT[${i}]}/etc/mkinitcpio.conf" "${MOUNTPOINT}/${MOUNT[${i}]}/etc/mkinitcpio.conf.pacsave"
    cat <<EOF > "${MOUNTPOINT}/${MOUNT[${i}]}/etc/mkinitcpio.conf"
MODULES=(ext4)
HOOKS=(base keyboard udev autodetect modconf block mdadm_udev multiencrypt lvm2 encrypt-dh filesystems fsck)
EOF
  fi

  genfstab -U -p "${MOUNTPOINT}/${MOUNT[${i}]}" | sed -e '/^[[:space:]]*$/d' -e '/\/dev\/zram/d' > "${MOUNTPOINT}/${MOUNT[${i}]}/etc/fstab"
  echo "GRUB_CMDLINE_LINUX_DEFAULT+=' cryptdevice=/dev/${VG_NAME}/${LV[${i}]}:${MOUNT[${i}]} cryptheader=/dev/mapper/${BOOTS[0]}:ext4:/headers/${MOUNT[${i}]}'" >>"${MOUNTPOINT}/${MOUNT[${i}]}/etc/default/grub"

  if [ "${i}" -eq 0 ]; then
    . "$(dirname "$(readlink -f "${0}")")/../finishes"
    INITRD_UPDATE_CMD="mkinitcpio -P" common_finish "${MOUNTPOINT}/${MOUNT[${i}]}"
    umount -R "${MOUNTPOINT}/${MOUNT[${i}]}/boot"
  else
    #arch-chroot "${MOUNTPOINT}/${MOUNT[${i}]}" /bin/bash -c 'grub-mkconfig -o /boot/grub/grub.cfg'
    :
  fi
done
