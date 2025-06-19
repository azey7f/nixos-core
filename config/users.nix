{
  lib,
  azLib,
  config,
  pkgs,
  ...
}:
with lib; let
  users = config.az.core.users;
in {
  options.az.core.users = mkOption {
    type = with types;
      attrsOf (submodule ({name, ...}: {
        options = with azLib.opt; {
          enable = optBool false;
          name = mkOption {
            type = with types; passwdEntry str;
            default = name;
          };
          sshKeys = mkOption {
            type = with types; listOf singleLineStr;
            default = [];
          };
          home = {
            path = mkOpt path "/home/${name}";
            stateVersion = optStr config.system.stateVersion;
          };
        };
      }));
    default = {};
  };

  config = with lib.attrsets;
    mkIf (length (mapAttrsToList (n: v: v.enable) users) > 0) {
      security.sudo.enable = lib.mkForce true;
      security.sudo.wheelNeedsPassword = false;

      nix.settings.allowed-users = lib.mapAttrsToList (name: _: name) users;

      # For some reason coredumps aren't disabled by default
      systemd.user.extraConfig = "DefaultLimitCORE=0";

      users.users =
        attrsets.mapAttrs (name: cfg: {
          isNormalUser = true;
          extraGroups = ["wheel" "adbusers" "dialout"];
          shell = pkgs.fish;
          #packages = with pkgs; [];
          hashedPasswordFile = "/home/${name}/.passwd"; #TODO: sops-nix declarative?
          openssh.authorizedKeys.keys = cfg.sshKeys or config.svc.ssh.keys;
        })
        users;
    };
}
