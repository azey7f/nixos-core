# static systemd-networkd interface config
{
  config,
  azLib,
  lib,
  ...
}: let
  cfg = config.az.core.net;
in {
  options.az.core.net = with azLib.opt; {
    bridges = lib.mkOption {
      type = with lib.types;
        attrsOf (submodule ({name, ...}: {
          options = {
            enable = optBool false;
            name = lib.mkOption {
              type = lib.types.str;
              default = name;
            };

            interfaces = lib.mkOption {
              type = with lib.types; listOf str;
              default = [];
            };
          };
        }));
      default = {};
    };

    interfaces = lib.mkOption {
      type = with lib.types;
        attrsOf (submodule ({
          config,
          name,
          ...
        }: {
          options = {
            enable = optBool false;
            name = lib.mkOption {
              type = with lib.types; oneOf [str (listOf str)];
              default = name;
            };

            ipv4 = {
              addr = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
              };
              subnetSize = lib.mkOption {
                type = lib.types.ints.u8;
                default = 24;
              };
              gateway = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
              };

              dhcpClient = optBool false;
              dhcpServer = optBool false;
            };

            ipv6 = {
              addr = lib.mkOption {
                type = with lib.types; nullOr (listOf str);
                default = null;
              };
              subnetSize = lib.mkOption {
                type = lib.types.ints.u8;
                default = 64;
              };
              gateway = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
              };

              sendRA = optBool false;
              acceptRA = optBool false;
              privacyExt = optBool false;
            };

            onlineWhen = optStr "routable";

            extraRoutes = lib.mkOption {
              type = with lib.types; listOf attrs;
              default = [];
            };

            vlans = lib.mkOption {
              # final vlan interfaces will be named "${name}.${id}"
              type = with lib.types; listOf ints.positive; # physical VLAN ids
              default = [];
            };

            wireguard = {
              # a wg netdev is created if privateKeyFile != null
              privateKeyFile = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
              };
              peers = lib.mkOption {
                type = with lib.types; listOf attrs;
                default = [];
              };
              routeTable = optStr "main"; # see systemd-netdev(5)
            };
          };
        }));
      default = {};
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      lib.mapAttrsToList (name: iface: {
        assertion = builtins.typeOf iface.name == "string" || iface.vlans == [];
        message = "az.core.net.interfaces.${name}: multiple names cannot be defined if vlans are defined";
      })
      cfg.interfaces;

    # force systemd-networkd
    networking.useDHCP = lib.mkForce false;
    networking.interfaces = lib.mkForce {};

    systemd.network = {
      enable = true;

      links = {
        # non-persistent MAC addrs
        "00-bridges" = {
          matchConfig.Type = "bridge";
          linkConfig.MACAddressPolicy = "none";
        };
      };

      netdevs = lib.mergeAttrsList (lib.flatten [
        # define VLANs
        (lib.mapAttrsToList (name: iface:
          builtins.map (id: {
            "10-${name}-vlan${toString id}" = {
              netdevConfig = {
                Kind = "vlan";
                Name = "${iface.name}.${toString id}";
              };
              vlanConfig.Id = id;
            };
          })
          iface.vlans)
        cfg.interfaces)

        # define bridges
        (lib.mapAttrs' (name: bridge:
          lib.nameValuePair "10-${name}" {
            netdevConfig = {
              Kind = "bridge";
              Name = bridge.name;
            };
          })
        cfg.bridges)

        # define wireguard ifaces
        (lib.mapAttrs' (name: iface:
          lib.nameValuePair "10-${name}" {
            netdevConfig = {
              Kind = "wireguard";
              Name = iface.name;
            };
            wireguardConfig = {
              PrivateKeyFile = iface.wireguard.privateKeyFile;
              RouteTable = iface.wireguard.routeTable;
            };
            wireguardPeers = iface.wireguard.peers;
          })
        (lib.filterAttrs (_: v: v.wireguard.privateKeyFile != null) cfg.interfaces))
      ]);

      networks = lib.mergeAttrsList (lib.flatten [
        # setup interfaces
        (lib.mapAttrs' (name: iface:
          lib.nameValuePair "20-${name}" {
            matchConfig.Name = iface.name;

            bridgeConfig = {}; # necessary for bridges, doesn't seem to break anything for non-bridges
            networkConfig = {
              ConfigureWithoutCarrier =
                if !(iface.ipv4.dhcpClient || iface.ipv6.acceptRA)
                then "yes"
                else "no";

              DHCP =
                if iface.ipv4.dhcpClient
                then "yes"
                else "no";
              DHCPServer =
                if iface.ipv4.dhcpServer
                then "yes"
                else "no";

              IPv6AcceptRA =
                if iface.ipv6.acceptRA
                then "yes"
                else "no";
              IPv6SendRA =
                if iface.ipv6.sendRA
                then "yes"
                else "no";
              IPv6PrivacyExtensions =
                if iface.ipv6.privacyExt
                then "yes"
                else "no";
            };
            dhcpServerConfig = lib.mkIf iface.ipv4.dhcpServer {
              EmitRouter = "yes";
              EmitTimezone = "yes";
              PoolOffset = 128;
            };
            ipv6Prefixes = lib.optionals iface.ipv6.sendRA (map (Prefix: {inherit Prefix;}) cfg.ipv6);

            address = lib.flatten [
              (lib.optional (iface.ipv4.addr != null)
                "${iface.ipv4.addr}/${toString iface.ipv4.subnetSize}")
              (lib.optional (iface.ipv6.addr != null)
                (map (ip: "${ip}/${toString iface.ipv6.subnetSize}") iface.ipv6.addr))
            ];
            routes =
              lib.flatten [
                (lib.optional (iface.ipv4.gateway != null) {Gateway = iface.ipv4.gateway;})
                (lib.optional (iface.ipv6.gateway != null) {Gateway = iface.ipv6.gateway;})
              ]
              ++ iface.extraRoutes;
            linkConfig.RequiredForOnline = iface.onlineWhen;

            vlan = builtins.map (vlan: "${iface.name}.${toString vlan}") iface.vlans;
          })
        cfg.interfaces)

        # connect interfaces to bridges
        (lib.mapAttrsToList (name: bridge: (
            builtins.map (iface: {
              "30-${iface}-${name}" = {
                matchConfig.Name = iface;
                networkConfig.Bridge = bridge.name;
                linkConfig.RequiredForOnline = "enslaved";
              };
            })
            bridge.interfaces
          ))
          cfg.bridges)
      ]);
    };
  };
}
