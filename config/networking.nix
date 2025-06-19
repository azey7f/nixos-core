{
  config,
  lib,
  azLib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.az.core.net;
in {
  options.az.core.net = with azLib.opt; {
    enable = optBool false;
    systemdDefault = optBool false;
    useIwd = optBool false;

    dns = {
      enable = optBool false;
      nameservers = mkOption {
        type = with types; listOf str;
        default = ["9.9.9.9"];
      };
    };
  };

  config = mkIf cfg.enable {
    services.resolved.enable = !cfg.dns.enable;
    environment.etc."resolv.conf".text = mkIf cfg.dns.enable (
      (strings.concatStrings (map (ns: "nameserver ${ns}\n") cfg.dns.nameservers))
      + "options edns0 trust-ad\n"
    );

    networking.hosts = {
      "127.0.0.2" = lib.mkForce [];
      "127.0.0.1" = lib.mkForce ["localhost"];
      "::1" = lib.mkForce ["localhost"];
    };

    networking.useDHCP = mkDefault (!cfg.systemdDefault);
    systemd.network = mkIf cfg.systemdDefault {
      enable = true;
      networks."10-wan" = {
        matchConfig.Name = ["enp*" "eno*" "eth*"];
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = true;
        };
        linkConfig.RequiredForOnline = "routable";
      };
    };

    networking.wireless.iwd = mkIf cfg.useIwd {
      enable = true;
      settings = {
        IPv6.Enabled = true;
        Settings.AutoConnect = mkDefault true;
      };
    };
  };
}
