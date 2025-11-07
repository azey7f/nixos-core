{
  config,
  azLib,
  lib,
  ...
}: let
  cfg = config.az.core.net;
in {
  options.az.core.net.firewall = lib.mkOption {
    type = with lib.types;
      attrsOf (submodule (
        {name, ...}: let
          ipVersion = name;
        in {
          freeformType = attrsOf (submodule ({name, ...}: let
            table = name;
          in {
            freeformType = attrsOf (submodule ({name, ...}: {
              options = with azLib.opt; {
                ipVersion = lib.mkOption {
                  type = enum ["v6" "v4" "all"];
                  default = ipVersion;
                };
                table = optStr table;
                name = optStr name;

                # whether to create/delete the chain
                managed = optBool false;

                default = optStr (
                  if table == "filter"
                  then "DROP"
                  else "ACCEPT"
                );
                rules = lib.mkOption {
                  type = listOf str;
                  default = [];
                };
              };
            }));
          }));
        }
      ));
    default = {};
    example."46".FORWARD.rules = [
      "-i eth0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT"
      "-i eth0 -j DROP"
    ];
  };

  config = lib.mkIf cfg.enable {
    networking.firewall = let
      createCommands = chainOp: ruleOp:
        lib.concatMapStringsSep "\n" (tables: (
          lib.concatMapStringsSep "\n" (chains: (
            lib.concatMapStringsSep "\n" (chain: let
              ipt = "ip${{
                  v4 = "";
                  v6 = "6";
                  all = "46"; # https://github.com/NixOS/nixpkgs/blob/4278b522634f050f5229edade93230b73da28fc3/nixos/modules/services/networking/helpers.nix
                }.${
                  chain.ipVersion
                }}tables";
            in (
              "${ipt} -t ${chain.table} -P ${chain.name} ${
                if chainOp == "-N"
                then chain.default
                else "ACCEPT"
              }\n"
              + lib.optionalString chain.managed "${ipt} -t ${chain.table} ${chainOp} ${chain.name}\n"
              + lib.concatMapStringsSep "\n" (rule: "${ipt} -t ${chain.table} ${ruleOp} ${chain.name} ${rule}") (lib.reverseList chain.rules)
            ))
            (builtins.attrValues chains)
          ))
          (builtins.attrValues tables)
        ))
        (builtins.attrValues cfg.firewall);
    in {
      extraCommands = createCommands "-N" "-I";
      extraStopCommands = createCommands "-X" "-D";
    };
  };
}
