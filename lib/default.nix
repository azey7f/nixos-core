{lib, ...} @ args:
with lib; rec {
  math = import ./math.nix args;
  opt = import ./options.nix args;

  # PATHS
  ## https://github.com/EmergentMind/nix-config/blob/e68e8554dc82226e8158728222ca33a81d22d4b7/lib/default.nix
  scanPath = path:
    builtins.map (f: (path + "/${f}")) (
      builtins.attrNames (
        lib.attrsets.filterAttrs (
          path: _type:
            (_type == "directory") # include directories
            || (
              (path != "default.nix") # ignore default.nix
              && (lib.strings.hasSuffix ".nix" path) # include .nix files
            )
        ) (builtins.readDir path)
      )
    );
  scanPaths = lib.lists.concatMap (dir: map (n: "${dir}/${n}") (builtins.attrNames (builtins.readDir dir)));

  reverseFQDN = fqdn:
    lib.strings.concatStringsSep "." (
      lib.lists.reverseList (lib.strings.splitString "." fqdn)
    );
}
