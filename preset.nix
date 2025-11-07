{lib, ...}:
with lib; {
  az.core = {
    firmware.enable = mkDefault true;
    hardening.enable = mkDefault true;
    net.enable = mkDefault true;
    net.firewall."46" = {
      OUTPUT.default = "ACCEPT";
      INPUT.default = "DROP";
      FORWARD.default = "DROP";

      INPUT.rules = ["-m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT"];
    };

    locale.enable = mkDefault true;
    programs.enable = mkDefault true;
    home.enable = mkDefault true;

    nix.enable = mkDefault true;
  };

  az.svc.usbguard.enable = true;
}
