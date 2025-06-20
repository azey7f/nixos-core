{
  lib,
  config,
  inputs,
  ...
}: {
  imports = [inputs.nixos-hardware.nixosModules.framework-13-7040-amd];

  networking.hostName = "selene";
  networking.hostId = "7e5a826f";
  networking.domain = "azey.net";
  system.stateVersion = config.system.nixos.release; # / is on tmpfs, so this should be fine

  az.core = {
    firmware.enable = true;
    boot.loader.grub.enable = true;
  };

  az.desktop = {
    graphics.amdgpu.enable = true;

    environment.hyprland = lib.mkIf (config.specialisation != {}) {
      enable = true;
      autoLogin.user = "main";

      services.waybar.tempSensor = "/sys/class/hwmon/hwmon1/temp1_input";
      services.hyprpaper.monitors."".wallpaper = "aurora.jpg";

      monitors."desc:BOE NE135A1M-NY1" = {
        resolution = "2880x1920@120";
        scale = 2;
        extraArgs = ", vrr, 1";
      };
    };
  };

  specialisation.KDE.configuration.az.desktop.environment.kde = {
    enable = true;
    session = "plasmax11";
    autoLogin.user = "main";
  };

  /*
    TODO az.server = {
    libvirt.enable = true;
    libvirt.vfio = false;
  };
  */
  users.users.main.extraGroups = ["libvirtd"];
}
