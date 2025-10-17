{
  config,
  azLib,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.az.svc.usbguard;
in {
  options.az.svc.usbguard = with azLib.opt; {
    enable = optBool false;
    allowAllPreconnected = optBool false;

    allowHubs = optBool true;
    allowStorage = optBool true;
    allowIO = mkOption {
      type = with types; enum ["none" "all" "first"];
      default = "none";
    };

    extraAllow = optStr "";
  };

  config = mkIf cfg.enable {
    services.usbguard = {
      enable = true;
      IPCAllowedUsers = ["root"];
      presentDevicePolicy =
        if cfg.allowAllPreconnected
        then "allow"
        else "apply-policy";
      presentControllerPolicy =
        if cfg.allowAllPreconnected
        then "allow"
        else "apply-policy";
      rules =
        ''
          # Reject devices with suspicious combinations of interfaces
          reject with-interface all-of { 08:*:* 03:00:* }
          reject with-interface all-of { 08:*:* 03:01:* }
          reject with-interface all-of { 08:*:* e0:*:* }
          reject with-interface all-of { 08:*:* 02:*:* }

          # hubs
          ${
            if cfg.allowHubs
            then ''
              allow with-interface equals { 09:00:* }
              allow with-interface equals { 09:00:* 09:00:* }
            ''
            else ""
          }

          # usb mass storage
          ${
            if cfg.allowStorage
            then "allow with-interface equals { 08:*:* }"
            else ""
          }

          # mice and keyboards
          ${
            {
              "all" = ''
                allow with-interface equals { 03:*:* }
              '';
              "first" = ''
                allow with-interface one-of { 03:00:01 03:01:01 } if !allowed-matches(with-interface one-of { 03:00:01 03:01:01 })
                allow with-interface one-of { 03:00:02 03:01:02 } if !allowed-matches(with-interface one-of { 03:00:02 03:01:02 })
              '';
              "none" = "";
            }.${
              cfg.allowIO
            }
          }
        ''
        + cfg.extraAllow;
    };

    environment.systemPackages = [pkgs.usbguard];
  };
}
