{
  config,
  lib,
  azLib,
  ...
}:
with lib; let
  cfg = config.az.core.users;
in {
  imports = azLib.scanPath ./.;

  options.az.core.home.enable = mkOption {
    type = types.bool;
    default = true;
  };

  config = mkIf config.az.core.home.enable {
    home-manager.users =
      (attrsets.mapAttrs (name: _: {
          home.username = name;
          home.homeDirectory = mkForce cfg.${name}.home.path;
          home.stateVersion = cfg.${name}.home.stateVersion;
        })
        config.az.core.users)
      // {
        root.home = {
          username = "root";
          homeDirectory = mkForce "/root";
          stateVersion = "25.05"; #config.system.stateVersion;
        };
      };
  };
}
