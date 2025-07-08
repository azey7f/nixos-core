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

  options.az.core.home.enable = azLib.opt.optBool false;

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
          stateVersion = config.system.stateVersion;
        };
      };
  };
}
