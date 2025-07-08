inputs: let
  lib = inputs.nixpkgs.lib;
  certs = ./.;
in
  builtins.listToAttrs (builtins.map (name: {
      name = lib.strings.removeSuffix ".crt" name;
      value = builtins.readFile "${certs}/${name}";
    }) (
      builtins.filter (
        lib.strings.hasSuffix ".crt"
      ) (builtins.attrNames (builtins.readDir certs))
    ))
