{
  pkgs,
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
      largeFont = optBool false;
    };
    config = mkIf cfg.enable {
      time.timeZone = cfg.tz;
      i18n.defaultLocale = "en_US.UTF-8";
      console = {
        font =
          if cfg.largeFont
          then "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz"
          else "Lat2-Terminus16";
        packages = lib.optional cfg.largeFont pkgs.terminus_font;
        keyMap = lib.mkForce cfg.keymap;
        useXkbConfig = true;
      };
    };
  }
