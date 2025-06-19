{
  description = "core lib & config defs for azey.net systems";

  inputs = {
    # all of these should be auto-updated
    nixpkgs.url = "nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    home-manager-unstable.url = "github:nix-community/home-manager/master";
    home-manager-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  outputs = {self, ...} @ inputs: let
    inherit (self) outputs;
  in {
    formatter.x86_64-linux = inputs.nixpkgs.legacyPackages.x86_64-linux.alejandra;
    formatter.aarch64-linux = inputs.nixpkgs.legacyPackages.aarch64-linux.alejandra;

    templates.default = {
      path = ./template;
      description = "azey.net system type flake template";
    };

    # function for creating outputs.nixosConfigurations in downstream flakes
    mkHostConfigurations = {
      # path to host configs, usually ./hosts
      path,
      # nixpkgs system arg
      system ? "x86_64-linux",
      # extra modules added to all systems
      modules ? [],
      # extra stuff passed to each module using _module.args
      extraArgs ? {},
      # extra stuff passed to nixosSystem's specialargs
      specialArgs ? {},
      # attrset, can contain "nixpkgs", "unstable", and/or "home-manager"
      # each attr is an attrset of:
      #   ref: a reference to the channel input, ex. inputs.nixpkgs
      #   config: for "nixpkgs" and "unstable", this is passed to nixpkgs on import along with system
      # by default, this flake's inputs are used with an empty config
      channels ? {},
    }:
      builtins.listToAttrs (
        map (name: {
          inherit name;
          value = let
            nixpkgs = channels.nixpkgs or {ref = inputs.nixpkgs;};
            unstable = channels.unstable or nixpkgs;
            home-manager = channels.home-manager.ref or inputs.home-manager;
          in
            nixpkgs.ref.lib.nixosSystem {
              inherit system;

              pkgs = import nixpkgs.ref {
                inherit system;
                config = nixpkgs.config or {};
              };

              specialArgs =
                {
                  azLib = import ./lib {inherit (nixpkgs.ref) lib;};
                  unstable = import unstable.ref {
                    inherit system;
                    config = unstable.config or {};
                  };
                }
                // specialArgs;

              modules =
                modules
                ++ [
                  # options.az.* defs
                  ./config
                  ./services

                  # misc modules
                  home-manager.nixosModules.home-manager

                  # host
                  {_module.args = extraArgs;}
                  "${path}/${name}"
                ];
            };
        }) (builtins.attrNames (builtins.readDir path))
      );
  };
}
