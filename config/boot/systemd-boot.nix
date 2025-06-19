{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.az.core.boot;
in {
  config = mkIf cfg.loader.systemd-boot.enable {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = false;
  };
}
