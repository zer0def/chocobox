# shellcheck disable=SC1090
. "$(dirname "$(readlink -f "${0}")")/../config"
# shellcheck disable=SC1090
. "$(dirname "$(readlink -f "${0}")")/../common"

nix-env -ib envsubst

#prep_bios_uefi
prep_uefi_only

. "$(dirname "$(readlink -f "${0}")")/../cleanups"
trap lvm_cleanup INT QUIT TERM EXIT

. "$(dirname "$(readlink -f "${0}")")/../setups"
lvm_setup

# shellcheck disable=SC2004
for i in $(seq 0 $((${ROOT_COUNT}-1))); do
  mount -t tmpfs none /mnt
  mkdir -p /mnt/boot
  mount "/dev/mapper/${BOOTS[0]}" /mnt/boot
  mkdir -p /mnt/boot/efi /mnt/boot/headers /mnt/nix ${NIXOS_PERSIST_MOUNTS[@]/#/\/mnt}
  mount "${ESPS[0]}" /mnt/boot/efi
  rsync -xaSPAX -zz "${HEADER_TMPDIR}/" /mnt/boot/headers/
  mount "/dev/mapper/${MOUNT[${i}]}" /mnt/nix
  for j in ${NIXOS_PERSIST_MOUNTS[@]}; do mkdir -p "/mnt/nix/persist${j}"; mount -o bind "/mnt/nix/persist${j}" "/mnt${j}"; done

  nixos-generate-config --no-filesystems --root /mnt
  sed -i '/boot.initrd.luks.devices/d' /mnt/etc/nixos/hardware-configuration.nix
  cat <<EOF >/mnt/etc/nixos/configuration.nix
{ config, pkgs, ... }: {
  imports = [ ./hardware-configuration.nix ];
  users.mutableUsers = false;
  users.users.root.initialPassword = "hunter2";
  #users.users.root.initialHashedPassword = "hunter2";

  environment = {
    systemPackages = with pkgs; [
      vim
    ];
    etc = {
      "machine-id".source = "/nix/persist/etc/machine-id";
      "ssh/ssh_host_ed25519_key".source = "/nix/persist/etc/ssh/ssh_host_ed25519_key";
      "ssh/ssh_host_ed25519_key.pub".source = "/nix/persist/etc/ssh/ssh_host_ed25519_key.pub";
    };
  };

  fileSystems = {
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = ["defaults" "size=2G" "mode=755"];
    };
    "/boot" = {
      device = "/dev/mapper/boot-${BOOTS[0]}";
      fsType = "ext4";
    };
    "/boot/efi" = {
      device = "${ESPS[0]}";
      fsType = "vfat";
    };
    "/nix" = {
      device = "/dev/mapper/${MOUNT[${i}]}";
      fsType = "ext4";
    };
  };

  boot = {
    initrd = {
      # UEFI-exclusive
      mdadmConf = ''
$(mdadm --detail --scan | sed 's/^/        /g')
      '';
      luks.devices = {
EOF
  for j in $(seq 0 $((${#BOOTS[@]}-1))); do
  cat <<EOF >>/mnt/etc/nixos/configuration.nix
        "boot-${BOOTS[${j}]}" = {
          device = "${BOOT_BACKINGS[${j}]}";
          preLVM = true;
          postOpenCommands = ''
            mkdir -p /boot
            mount -t ext4 "/dev/mapper/boot-${BOOTS[0]}" /boot ||:
          '';
        };
EOF
  done
  for j in $(seq 0 $((${#DETACHED_LUKS[@]}-1))); do
  cat <<EOF >>/mnt/etc/nixos/configuration.nix
        "pv-${DETACHED_LUKS[${j}]}" = {
          device = "${DETACHED_LUKS_BACKINGS[${j}]}";
          header = "/boot/headers/${DETACHED_LUKS[${j}]}";
          preLVM = true;
          # can't run this preOpen, as it blocks on missing header availability
          #preOpenCommands = ''
          #  mkdir -p /boot
          #  mount "/dev/mapper/boot-${BOOTS[0]}" /boot ||:
          #'';
        };
EOF
  done
  cat <<EOF >>/mnt/etc/nixos/configuration.nix
        "${MOUNT[${i}]}" = {
          device = "/dev/${VG_NAME}/${LV[${i}]}";
          header = "/boot/headers/${MOUNT[${i}]}";
          preLVM = false;
        };
      };
    };
    loader = {
      efi = {
        #canTouchEfiVariables = true;
        efiSysMountPoint = "/boot/efi";
      };
      grub = {
        enable = true;
        devices = ["${!BOOTDEVS}"];
        #mirroredBoots = [{
        #  devices = ["${ESPS[@]}"];
        #  path = "/";
        #}];
        version = 2;
        efiSupport = true;
        efiInstallAsRemovable = true;
        enableCryptodisk = true;
      };
    };
  };

  networking = {
    hostName = "nixos";
    useDHCP = false;
    wireless.enable = true;
    interfaces.eth0.useDHCP = true;
  };
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus10";
    keyMap = "us";
  };
  sound.enable = true;
  hardware.pulseaudio.enable = true;
  system.stateVersion = "21.11";
}
EOF
  nixos-install --show-trace --no-root-passwd --cores 0 --root /mnt
  umount -R /mnt
done
