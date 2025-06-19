{
  config,
  lib,
  azLib,
  ...
}:
with lib; let
  cfg = config.az.core.hardening;
in {
  options.az.core.hardening = with azLib.opt; {
    enable = optBool false;
    allowForwarding = optBool false;
    allowPing = optBool false;
  };

  config = mkIf cfg.enable {
    systemd.coredump.enable = false;
    security.sudo.enable = false;
    nix.settings.allowed-users = ["root"];
    environment.defaultPackages = lib.mkForce [];
    #nix.settings.substitute = false; # disable binary caches

    boot.kernel.sysctl = {
      "net.ipv4.conf.all.forwarding" = cfg.allowForwarding;
      "net.ipv6.conf.all.forwarding" = cfg.allowForwarding;
      "net.ipv4.ip_forward" = cfg.allowForwarding;
      "net.ipv4.conf.all.accept_source_route" = false;
      "net.ipv4.conf.all.mc_forwarding" = false;
      "net.ipv6.conf.all.mc_forwarding" = false;
      "net.ipv4.conf.all.accept_redirects" = false;
      "net.ipv6.conf.all.accept_redirects" = false;
      "net.ipv4.conf.all.secure_redirects" = false;
      "net.ipv4.conf.all.send_redirects" = false;
      "net.ipv4.conf.default.send_redirects" = false;
      "net.ipv6.conf.all.accept_ra" = false;
      "net.ipv4.conf.all.rp_filter" = true;
      "net.ipv4.tcp_syncookie" = true;
      "net.ipv4.conf.default.log_martians" = true;
      "net.ipv4.icmp_echo_ignore_broadcasts" = true;
      "net.ipv4.tcp_fin_timeout" = 30;
      "net.ipv4.tcp_keepalive_intvl" = 10;
      "net.ipv4.tcp_keepalive_probes" = 3;
    };

    networking.firewall = {
      allowPing = mkDefault cfg.allowPing;
    };
  };
}
