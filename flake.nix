{
  description = "core lib & config defs for azey.net systems";

  inputs = {
    # all of these should be auto-updated
    nixpkgs.url = "git+https://git.azey.net/mirrors/nixpkgs?shallow=1&ref=nixos-25.05";
    nixpkgs-unstable.url = "git+https://git.azey.net/mirrors/nixpkgs?shallow=1&ref=nixos-unstable";

    home-manager.url = "git+https://git.azey.net/mirrors/home-manager?shallow=1&ref=release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    home-manager-unstable.url = "git+https://git.azey.net/mirrors/home-manager?shallow=1&ref=master";
    home-manager-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

    disko.url = "git+https://git.azey.net/mirrors/disko?shallow=1&ref=refs/tags/latest"; # https://github.com/NixOS/nix/issues/5291
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {self, ...} @ inputs: let
    inherit (self) outputs;
  in rec {
    formatter.x86_64-linux = inputs.nixpkgs.legacyPackages.x86_64-linux.alejandra;
    formatter.aarch64-linux = inputs.nixpkgs.legacyPackages.aarch64-linux.alejandra;

    templates.default = {
      path = ./template;
      description = "azey.net system type flake template";
      welcomeText = ''
        ## to initialize the git repo & nixos-core submodule, run these commands:
        git init -b main\
        git submodule add -b main https://git.azey.net/infra/nixos-core core\
        git add -A
      '';
    };

    # CA certificates
    certs = import ./certs inputs;

    # function for creating outputs.hydraJobs from nixosConfigurations in downstream flakes
    mkHydraJobs = builtins.mapAttrs (name: system: system.config.system.build.toplevel);

    # function for creating outputs.nixosConfigurations in downstream flakes
    mkHostConfigurations = {
      # path to host configs, usually ./hosts
      path,
      ...
    } @ args:
      builtins.listToAttrs (
        map (name: {
          inherit name;
          value = mkHostConf args name;
        }) (builtins.attrNames (builtins.readDir path))
      );

    # function for creating an outputs.nixosConfigurations entry, useful for e.g. creating multiple configs from a single dir
    mkHostConf = {
      path,
      # nixpkgs system arg
      system ? "x86_64-linux",
      # extra modules added to all systems
      modules ? [],
      # extra stuff passed to each module using _module.args
      extraArgs ? {},
      # extra stuff passed to nixosSystem's specialargs
      specialArgs ? {},
      # attrset, can contain "nixpkgs", "unstable", "home-manager" and/or "disko"
      # each attr is an attrset of:
      #   ref: a reference to the channel input, ex. inputs.nixpkgs
      #   config: for "nixpkgs" and "unstable", this is passed to nixpkgs on import along with system
      # by default, this flake's inputs are used with an empty config
      channels ? {},
    }: name: let
      nixpkgs = channels.nixpkgs or {ref = inputs.nixpkgs;};
      unstable = channels.unstable or nixpkgs;
      home-manager = channels.home-manager.ref or inputs.home-manager;
      disko = channels.disko.ref or inputs.disko;
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
          [
            # misc modules
            home-manager.nixosModules.home-manager
            disko.nixosModules.disko

            # options.az.core and options.az.svc defs
            ./config
            ./services

            # preset values for core options
            #  could've been in ./config itself, but this makes it
            #  easy to check what is and isn't enabled by default
            ./preset.nix
          ]
          ++ modules
          ++ [
            # host
            {_module.args = extraArgs;}
            "${path}/${name}"
          ];
      };
  };
}
