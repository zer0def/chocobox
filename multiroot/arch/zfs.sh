#!/bin/bash -ex

# shellcheck disable=SC1090
. "$(dirname "$(readlink -f "${0}")")/../config"
# shellcheck disable=SC1090
. "$(dirname "$(readlink -f "${0}")")/../common"
. "$(dirname "$(readlink -f "${0}")")/common"

arch_zfs_finish(){
  local i="${1}"

  # refer to: /etc/zfs/zed.d/history_event-zfs-list-cacher.sh
  PROPS="name,mountpoint,canmount,atime,relatime,devices,exec,readonly,setuid,nbmand,encroot,keylocation,org.openzfs.systemd:requires,org.openzfs.systemd:requires-mounts-for,org.openzfs.systemd:before,org.openzfs.systemd:after,org.openzfs.systemd:wanted-by,org.openzfs.systemd:required-by,org.openzfs.systemd:nofail,org.openzfs.systemd:ignore"
  mkdir -p "${MOUNTPOINT}/etc/zfs/zfs-list.cache"
  zfs list -H -t filesystem -r "${DATASET[${i}]}" -o "${PROPS}" | sed -E "s#${MOUNTPOINT}/?#/#g" > "${MOUNTPOINT}/etc/zfs/zfs-list.cache/${ZPOOL_NAME//\//-}"
}

trap zfs_cleanup INT QUIT TERM EXIT

prep_bios_uefi
#prep_uefi_only

zfs_setup "${MOUNTPOINT}"

# shellcheck disable=SC2004
for i in $(seq 0 $((${ROOT_COUNT}-1))); do
  if [ "${i}" -eq 0 ]; then  # bootstrap the template
    zfs create -o mountpoint=/ -o canmount=noauto "${ROOTFS[${i}]}"
    zfs mount -Ol "${ROOTFS[${i}]}"
    for j in "${!MOUNTPOINT_MAP[@]}"; do
      k="${j}[${i}]"
      zfs create -o mountpoint="${MOUNTPOINT_MAP[${j}]}" -o canmount=on "${!k}"
    done

    DISTRO=arch common_bootstrap "${MOUNTPOINT}"

    curl -sSL https://archzfs.com/archzfs.gpg | arch-chroot "${MOUNTPOINT}" pacman-key -a -
    arch-chroot "${MOUNTPOINT}" /bin/sh <<'EOF'
pacman-key --lsign-key DDF7DB817396A49B2A2723F7403BD972F75D9D76
cat <<'EOD' >>/etc/pacman.conf
[archzfs]
Server = http://archzfs.com/$repo/x86_64
EOD
pacman --noconfirm -Sy zfs-dkms
systemctl enable zfs-import-scan.service zfs-import.target zfs-mount zfs-zed zfs.target
EOF

    cp "${MOUNTPOINT}/etc/mkinitcpio.conf" "${MOUNTPOINT}/etc/mkinitcpio.conf.pacsave"
    cat <<EOF > "${MOUNTPOINT}/etc/mkinitcpio.conf"
MODULES=(ext4)
HOOKS=(base keyboard udev autodetect modconf block mdadm_udev multiencrypt zfs filesystems fsck)
EOF

    sed -i "s#rpool=.*#rpool=\`zdb -l \${GRUB_DEVICE} | awk -F\"'\" '/[[:blank:]]name:[[:blank:]]/ {print \$2}'\`#" "${MOUNTPOINT}/etc/grub.d/10_linux"
    #sed -i "s#LINUX_ROOT_DEVICE=\"ZFS=.*#LINUX_ROOT_DEVICE=\"zfs zfs=\`zdb -l \${GRUB_DEVICE} | awk -F\"'\" '/[[:blank:]]name:[[:blank:]]/ {print \$2}'\`\"#" "${MOUNTPOINT}/etc/grub.d/10_linux"

    arch_zfs_finish "${i}"

    # generate non-zfs mountpoints
    genfstab -U -p "${MOUNTPOINT}" | sed -e "/${DATASET[${i}]//\//\\/}/d" -e '/^[[:space:]]*$/d' -e '/\/dev\/zram/d' > "${MOUNTPOINT}/etc/fstab"

    INITRD_UPDATE_CMD="mkinitcpio -P" common_finish "${MOUNTPOINT}"
  else
    # `zfs send` - data decrypted by source and re-encrypted by the destination
    # `zfs send -r` - raw (possibly ciphertext) data sent by source to destination
    zfs send -Lec "${ROOTFS[0]}" | pv -trabW | zfs receive -Feu "${DATASET[${i}]}"
    zfs rename -u "${DATASET[${i}]}/${ROOTFS[0]##*/}" "${ROOTFS[${i}]}"
    zfs set mountpoint=/ canmount=noauto "${ROOTFS[${i}]}"
    zfs destroy "${ROOTFS[${i}]}@--head--"
    zfs mount -l "${ROOTFS[${i}]}"

    for j in ${!MOUNTPOINT_MAP[@]}; do
      k="${j}[0]" l="${j}[${i}]"
      zfs send -Lec "${!k}" | pv -trabW | zfs receive -Feu "${DATASET[${i}]}"
      zfs rename -u "${DATASET[${i}]}/${!k##*/}" "${!l}"
      zfs set mountpoint="${MOUNTPOINT_MAP[${j}]:-/}" canmount=on "${!l}"
      zfs destroy "${!l}@--head--"
    done

    arch_zfs_finish "${i}"
  fi
  umount -R "${MOUNTPOINT}"
done
