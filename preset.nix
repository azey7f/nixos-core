{lib, ...}:
with lib; {
  az.core = {
    firmware.enable = mkDefault true;
    hardening.enable = mkDefault true;
    net.enable = mkDefault true;

    locale.enable = mkDefault true;
    programs.enable = mkDefault true;
    home.enable = mkDefault true;

    nix.enable = mkDefault true;
  };

  az.svc.usbguard.enable = true;
}
