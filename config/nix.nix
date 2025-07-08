# https://github.com/EmergentMind/nix-config/blob/1662320c73e1721f496a54c49a3b74aa3f66972c/hosts/common/core/default.nix #L70-L101
{
  inputs,
  config,
  lib,
  azLib,
  pkgs,
  unstable,
  ...
}:
with lib; {
  options.az.core.nix.enable = azLib.opt.optBool false;

  config = mkIf config.az.core.nix.enable {
    nix = {
      package = unstable.nixVersions.latest;

      # This will add each flake input as a registry
      # To make nix3 commands consistent with your flake
      #TODO registry = lib.mapAttrs (_: value: {flake = value;}) inputs;

      # This will add your inputs to the system's legacy channels
      # Making legacy nix commands consistent as well, awesome!
      nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

      settings = {
        # See https://jackson.dev/post/nix-reasonable-defaults/
        connect-timeout = 5;
        log-lines = 25;
        min-free = 128000000; # 128MB
        max-free = 1000000000; # 1GB

        trusted-users = ["@wheel"];
        # Deduplicate and optimize nix store
        auto-optimise-store = true;
        warn-dirty = false;

        allow-import-from-derivation = true;

        experimental-features = [
          "nix-command"
          "flakes"
        ];
      };

      # Garbage Collection
      gc = {
        automatic = true;
        options = "--delete-older-than 10d";
      };
    };
  };
}
