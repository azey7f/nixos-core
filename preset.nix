{lib, ...}:
with lib; {
  az.core = {
    firmware.enable = mkDefault true;
    hardening.enable = mkDefault true;
    locale.enable = mkDefault true;
    net.enable = mkDefault true;
    programs.enable = mkDefault true;
  };
}
