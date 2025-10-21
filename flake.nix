{
  description = "core lib & config defs for azey.net systems";

  inputs = {
    # all of these should be auto-updated
    nixpkgs.url = "git+https://git.azey.net/mirrors/NixOS--nixpkgs?shallow=1&ref=nixos-25.05";
    nixpkgs-unstable.url = "git+https://git.azey.net/mirrors/NixOS--nixpkgs?shallow=1&ref=nixos-unstable";

    home-manager.url = "git+https://git.azey.net/mirrors/nix-community--home-manager?ref=release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    home-manager-unstable.url = "git+https://git.azey.net/mirrors/nix-community--home-manager?ref=master";
    home-manager-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

    disko.url = "git+https://git.azey.net/mirrors/nix-community--disko?ref=refs/tags/latest"; # https://github.com/NixOS/nix/issues/5291
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

    # function for creating outputs.nixosConfigurations in downstream flakes
    mkHostConfigurations = {
      # path to host configs, usually ./hosts
      path,
      # see mkHostConf
      channels ? {},
      ...
    } @ args:
      builtins.listToAttrs (
        (channels.nixpkgs or {ref = inputs.nixpkgs;}).ref.lib.lists.concatMap
        (mkHostConf args) (builtins.attrNames (builtins.readDir path))
      );

    # function for creating outputs.nixosConfigurations entries tied to a host
    # useful downstream for e.g. creating multiple configs from a single dir
    # returns a listOf attrs with 2 elements - ${name} and ${name}-cross,
    # the second of which is built in CI
    mkHostConf = {
      path,
      # nixpkgs system arg
      system ? "x86_64-linux",
      # buildPlatform for the -cross config
      buildSystem ? "x86_64-linux",
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
      #   extraArgs: for "nixpkgs and "unstable", these are passed to the import next to system and config
      # by default, this flake's inputs are used with an empty config
      channels ? {},
    }: name: let
      processedChannels = rec {
        nixpkgs = channels.nixpkgs or {ref = inputs.nixpkgs;};
        unstable = channels.unstable or nixpkgs;
        home-manager = channels.home-manager.ref or inputs.home-manager;
        disko = channels.disko.ref or inputs.disko;
      };
      args = {
        # explicitly re-defined so the default values propagate
        inherit path system modules extraArgs specialArgs;
      };

      lib = processedChannels.nixpkgs.ref.lib;
    in [
      {
        inherit name;
        value = mkNixosSystem processedChannels args name;
      }
      {
        name = "${name}-cross";
        value = let
          crossChannels =
            if (system == buildSystem)
            then processedChannels
            else
              builtins.mapAttrs (n: v:
                v
                // {
                  extraArgs.buildPlatform = buildSystem;
                  extraArgs.hostPlatform = system;
                })
              processedChannels;
        in
          mkNixosSystem crossChannels args name;
      }
    ];

    # internal function, creates the individual nixosConfigurations
    mkNixosSystem = {
      nixpkgs,
      unstable,
      home-manager,
      disko,
    }: args: name:
      nixpkgs.ref.lib.nixosSystem {
        inherit (args) system;

        pkgs = import nixpkgs.ref ({
            inherit (args) system;
            config = nixpkgs.config or {};
          }
          // (nixpkgs.extraArgs or {}));

        specialArgs =
          {
            azLib = import ./lib {inherit (nixpkgs.ref) lib;};
            unstable = import unstable.ref ({
                inherit (args) system;
                config = unstable.config or {};
              }
              // (unstable.extraArgs or {}));
          }
          // args.specialArgs;

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
          ++ args.modules
          ++ [
            # host
            {_module.args = args.extraArgs;}
            "${args.path}/${name}"
          ];
      };
  };
}
