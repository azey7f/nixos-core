Hi there, hello! This flake contains the library & util functions imported by all of my other flakes, plus a template for generating new ones.

The general structure of all flakes, including this one, is this (any non-standard stuff should be documented in the flake's README):
- `config/`: contains all of the flake's generic `options.az.*` module defs, everything is disabled by default
- `services/`: defines `az.svc.*` options, used for misc services not necessarily useful to all hosts
- `preset.nix`: defines which `az.*` options are enabled by default for `hosts/` (or in this flake, by all downstreams' `hosts/`)
- `hosts/`: defines the actual systems, should ideally contain no redundant information. Not present in this flake for obvious reasons
- `core/`: a git submodule of this flake, imported in `flake.nix`

This flake also includes:
- `lib/`: `azLib` declaration, automatically imported by `mkHostConfigurations` into `specialArgs`
- `certs/`: at time of writing unused global certs
- `template/`: template of a flake using this one

These are the flake's outputs used in downstream flakes:
- `mkHostConfigurations`/`mkHostConf`: helper functions for creating `nixosConfigurations` - see `flake.nix` and `template/flake.nix`
- `mkHydraJobs`: helper function for creating `hydraJobs`, takes `nixosConfigurations` as an argument
