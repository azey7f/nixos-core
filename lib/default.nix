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

  # MISC
  strings = rec {
    zeroPad = len: n:
      if builtins.stringLength n < len
      then zeroPad (len - 1) "0${n}"
      else n;
  };

  toCredential = builtins.map (secret: "${builtins.replaceStrings ["/"] ["-"] secret}:/secrets/${secret}"); # used for systemd's LoadCredential in microvms
}
