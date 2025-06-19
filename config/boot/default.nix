{
  config,
  lib,
  azLib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.az.core.boot;
in {
  imports = azLib.scanPath ./.;

  options.az.core.boot = with azLib.opt; {
    loader.grub.enable = optBool false;
    loader.systemd-boot.enable = optBool false;

    efiVars = optBool false;

    fs = mkOption {
      type = with types;
        coercedTo
        (listOf str)
        (enabled: lib.listToAttrs (map (fs: lib.nameValuePair fs true) enabled))
        (attrsOf bool);
      default = ["ntfs"];
    };
  };

  config = {
    boot.supportedFilesystems = cfg.fs;
    boot.loader.efi.canTouchEfiVariables = cfg.efiVars;
  };
}
