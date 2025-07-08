{
  config,
  lib,
  azLib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.az.core.libvirt;
in {
  options.az.core.libvirt = with azLib.opt; {
    enable = optBool false;

    vfio = optBool true;
    customLogo = optBool true;

    hugepages = {
      enable = optBool false;
      count = mkOption {
        type = types.ints.positive;
        default = 8;
      };
    };
  };

  config = mkIf cfg.enable {
    boot.kernelModules = lists.optionals cfg.vfio ["vfio_virqfd" "vfio_pci" "vfio_iommu_type1" "vfio"];
    boot.kernelParams =
      (lists.optionals cfg.vfio [
        "iommu=pt"
      ])
      ++ (
        lists.optionals cfg.hugepages.enable [
          "default_hugepagesz=1G"
          "hugepagesz=1G"
          "hugepages=${toString cfg.hugepages.count}"
        ]
      );

    # custom UEFI boot logo
    nixpkgs.overlays = lists.optionals cfg.customLogo [
      (final: prev: {
        OVMF = prev.OVMF.overrideAttrs (old: {
          postPatch =
            (old.postPatch or "")
            + ''
              cp ${./arasaka.bmp} ./MdeModulePkg/Logo/Logo.bmp
            '';
        });
      })
    ];

    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;
        ovmf = {
          enable = true;
          packages = [
            (pkgs.OVMF.override {
              secureBoot = true;
              tpmSupport = true;
            })
            .fd
          ];
        };
      };
    };
  };
}
