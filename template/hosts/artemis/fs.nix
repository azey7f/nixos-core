{config, ...}: {
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = ["defaults" "size=32G" "mode=755"];
    neededForBoot = true;
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-label/ARTEMIS-ROOT";
    fsType = "btrfs";
    options = ["subvol=@nix"];
    neededForBoot = true;
  };

  fileSystems."/etc/nixos" = {
    device = "/dev/disk/by-label/ARTEMIS-ROOT";
    fsType = "btrfs";
    options = ["subvol=@nixos"];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-label/ARTEMIS-ROOT";
    fsType = "btrfs";
    options = ["subvol=@home"];
    neededForBoot = true;
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ARTEMIS-EFI";
    fsType = "vfat";
    options = ["umask=007"];
  };

  swapDevices = [];
}
