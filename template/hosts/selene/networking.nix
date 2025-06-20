{
  lib,
  config,
  ...
}: {
  az.core.net.useIwd = true;
  networking.useDHCP = false;

  systemd.network = {
    enable = true;

    netdevs."25-ethbr0".netdevConfig = {
      Name = "ethbr0";
      Kind = "bridge";
    };

    networks."30-ethbr0-connect" = {
      matchConfig.Type = "ether";
      networkConfig.Bridge = "ethbr0";
    };
    networks."35-ethbr0" = {
      matchConfig.Name = "ethbr0";
      bridgeConfig = {};
      networkConfig = {
        DHCP = "yes";
        IPv6AcceptRA = true;
      };
      linkConfig.RequiredForOnline = "routable";
    };
    networks."35-wireless" = {
      matchConfig.Type = "wlan";
      networkConfig = {
        DHCP = "yes";
        IPv6AcceptRA = true;
        IgnoreCarrierLoss = "3s";
      };
      linkConfig.RequiredForOnline = "routable";
    };
  };
}
