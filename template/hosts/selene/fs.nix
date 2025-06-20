{
  config,
  lib,
  ...
}:
with lib; {
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = ["defaults" "size=8G" "mode=755"];
    neededForBoot = true;
  };
  fileSystems."/nix".neededForBoot = true;
  fileSystems."/home".neededForBoot = true;

  disko.devices = {
    disk = {
      root = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            EFI = {
              priority = 1;
              name = "EFI";
              start = "1M";
              end = "1024M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            ZFS = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "nvme";
              };
            };
          };
        };
      };
    };

    zpool.nvme = {
      type = "zpool";

      rootFsOptions = {
        mountpoint = "none";
        compression = "zstd";
        acltype = "posixacl";
        xattr = "sa";
        encryption = "aes-256-gcm";
        keyformat = "passphrase";
        keylocation = "prompt";
      };
      options.ashift = "12";

      datasets = {
        "home" = {
          type = "zfs_fs";
          mountpoint = "/home";
        };
        "nix" = {
          type = "zfs_fs";
          mountpoint = "/nix";
        };
        "nix/nixos" = {
          type = "zfs_fs";
          mountpoint = "/etc/nixos";
        };
        "data/libvirt" = {
          type = "zfs_fs";
          mountpoint = "/var/lib/libvirt";
        };
        "data/iwd" = {
          type = "zfs_fs";
          mountpoint = "/var/lib/iwd";
        };
        "data/fprint" = {
          type = "zfs_fs";
          mountpoint = "/var/lib/fprint";
        };
        /*
        "swap" = {
          type = "zfs_volume";
          size = "64G";
          options.encryption = "off";
          content = {
            type = "swap";
            randomEncryption = true;
          };
        };
        */
      };
    };
  };
}
