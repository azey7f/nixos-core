{
  config,
  lib,
  azLib,
  ...
}:
with lib; let
  cfg = config.az.core.firmware;
in {
  options.az.core.firmware = with azLib.opt; {
    enable = optBool false;
    allowUnfree = optBool false;
    microcode = optStr "amd";
  };
  config = mkIf cfg.enable {
    hardware.enableAllFirmware = cfg.allowUnfree;
    hardware.enableRedistributableFirmware = true;
    hardware.cpu.${cfg.microcode}.updateMicrocode = true;

    services.fwupd.enable = true;
  };
}
