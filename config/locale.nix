{
  config,
  lib,
  azLib,
  ...
}: let
  cfg = config.az.core.locale;
in
  with lib; {
    options.az.core.locale = with azLib.opt; {
      enable = optBool false;
      tz = optStr "MET"; # CET/CEST
      keymap = optStr "colemak";
    };
    config = mkIf cfg.enable {
      time.timeZone = cfg.tz;
      i18n.defaultLocale = "en_US.UTF-8";
      console = {
        font = "Lat2-Terminus16";
        keyMap = lib.mkForce cfg.keymap;
        useXkbConfig = true;
      };
    };
  }
