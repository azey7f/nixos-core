{
  config,
  lib,
  azLib,
  ...
}:
with lib; {
  options.az.core.locale = with azLib.opt; {
    enable = optBool true;
  };
  config = mkIf config.az.core.locale.enable {
    time.timeZone = "Europe/Prague";
    i18n.defaultLocale = "en_US.UTF-8";
    console = {
      font = "Lat2-Terminus16";
      keyMap = lib.mkForce "colemak";
      useXkbConfig = true;
    };
  };
}
