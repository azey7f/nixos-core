{lib, ...}:
with lib; rec {
  # mkOption alias w/ description
  mkOpt' = type: default: description:
    mkOption {inherit type default description;};

  # mkOption alias w/o description
  mkOpt = type: default:
    mkOption {inherit type default;};

  # mkOpt <type> aliases
  optBool = mkOpt types.bool;
  optStr = mkOpt types.str;
}
