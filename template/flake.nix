{
  inputs = {
    self.submodules = true;
    core.url = "./core";
  };

  outputs = {
    self,
    core,
    ...
  } @ inputs: let
    inherit (self) outputs;
  in rec {
    inherit (core.outputs) formatter;

    nixosConfigurations = core.mkHostConfigurations {
      path = ./hosts;

      modules = [
        ./config
        ./services
        ./preset.nix
      ];
    };

    hydraJobs = core.mkHydraJobs nixosConfigurations;
  };
}
