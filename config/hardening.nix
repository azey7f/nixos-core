{
  config,
  lib,
  azLib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.az.core.hardening;
in {
  options.az.core.hardening = with azLib.opt; {
    enable = optBool false;

    allowForwarding = optBool false;
    allowPing = optBool false;

    malloc = optStr "graphene-hardened-light";
    virtFlushCache = optStr "always";
  };

  config = mkIf cfg.enable {
    # TODO: 700 perm on /home, umask 0077, FS nosuid et al
    # TODO: secure boot, apparmor?
    # TODO: fail2ban for sshd

    # nix
    nix.settings.allowed-users = ["root"];
    users.mutableUsers = false;

    # misc system stuff
    environment.defaultPackages = lib.mkForce [];
    systemd.coredump.enable = false;
    security.sudo.enable = false;

    networking.firewall = {
      enable = true; # TODO: nftables by default?
      allowPing = mkDefault cfg.allowPing;
    };

    # kernel stuff
    boot.kernelPackages = pkgs.linuxKernel.packages.linux_hardened;
    # security.lockKernelModules = true;
    security.protectKernelImage = true;
    security.virtualisation.flushL1DataCache = cfg.virtFlushCache;
    security.forcePageTableIsolation = false; # "pti=on" - perf impact: https://en.wikipedia.org/wiki/Kernel_page-table_isolation#Implementation

    security.allowUserNamespaces = true; # necessary for nix.settings.sandbox
    security.unprivilegedUsernsClone = false;

    boot.kernel.sysctl =
      (
        lib.attrsets.mergeAttrsList (builtins.map (ifaces: {
          "net.ipv4.conf.${ifaces}.forwarding" = cfg.allowForwarding;
          "net.ipv6.conf.${ifaces}.forwarding" = cfg.allowForwarding;
          "net.ipv4.conf.${ifaces}.accept_source_route" = false;
          "net.ipv6.conf.${ifaces}.accept_source_route" = false;
          "net.ipv4.conf.${ifaces}.mc_forwarding" = false;
          "net.ipv6.conf.${ifaces}.mc_forwarding" = false;
          "net.ipv4.conf.${ifaces}.accept_redirects" = false;
          "net.ipv6.conf.${ifaces}.accept_redirects" = false;
          "net.ipv4.conf.${ifaces}.secure_redirects" = false;
          "net.ipv4.conf.${ifaces}.send_redirects" = false;
          "net.ipv6.conf.${ifaces}.accept_ra" = false;
          "net.ipv4.conf.${ifaces}.rp_filter" = true;
          "net.ipv6.conf.${ifaces}.use_tempaddr" = mkForce 2;
        }) ["all" "default"])
      )
      // {
        # networking - TODO: randomize MAC addrs on boot
        "net.ipv4.ip_forward" = cfg.allowForwarding;
        "net.ipv4.tcp_syncookies" = true;
        "net.ipv4.tcp_rfc1337" = true;
        "net.ipv4.conf.default.log_martians" = true;
        "net.ipv4.icmp_echo_ignore_broadcasts" = true;
        "net.ipv4.tcp_fin_timeout" = 30;
        "net.ipv4.tcp_keepalive_intvl" = 10;
        "net.ipv4.tcp_keepalive_probes" = 3;
        "net.ipv4.tcp_sack" = false;
        "net.ipv4.tcp_dsack" = false;
        "net.ipv4.tcp_fack" = false;

        # https://madaidans-insecurities.github.io/guides/linux-hardening.html#sysctl-kernel
        "kernel.kptr_restrict" = 2;
        "kernel.dmesg_restrict" = true;
        "kernel.printk" = "3 3 3 3";
        "kernel.unprivileged_bpf_disabled" = true;
        "net.core.bpf_jit_harden" = 2;
        "dev.tty.ldisc_autoload" = false;
        "vm.unprivileged_userfaultfd" = false;
        "kernel.sysrq" = false;
        "kernel.perf_event_paranoid" = 3;

        # https://madaidans-insecurities.github.io/guides/linux-hardening.html#sysctl-userspace
        "kernel.yama.ptrace_scope" = 2;
        "vm.mmap_rnd_bits" = 32;
        "vm.mmap_rnd_compat_bits" = 16;
        "fs.protected_symlinks" = true;
        "fs.protected_hardlinks" = true;
        "fs.protected_fifos" = 2;
        "fs.protected_regular" = 2;

        # https://github.com/NixOS/nixpkgs/blob/9e19e8fbb5b180404cc2b130c51d578e3b7ef998/nixos/modules/profiles/hardened.nix#L104-L135
        "kernel.ftrace_enabled" = mkDefault false;
        # https://madaidans-insecurities.github.io/guides/linux-hardening.html#core-dumps
        "kernel.core_pattern" = "|/bin/false";
        "fs.suid_dumpable" = false;

        # https://saylesss88.github.io/nix/hardening_NixOS.html#further-hardening-with-sysctl
        "kernel.randomize_va_space" = 2;
        "kernel.exec-shield" = 1;
        "net.ipv4.tcp_fastopen" = 3;
        "net.ipv4.tcp_congestion_control" = "bbr";
        "net.core.default_qdisc" = "cake";
      };

    environment.memoryAllocator.provider = cfg.malloc;
    environment.variables = mkIf (cfg.malloc == "scudo") {
      SCUDO_OPTIONS = "zero_contents=true";
    };

    boot.kernelParams = [
      "random.trust_cpu=off" # might as well

      # https://tails.net/contribute/design/kernel_hardening/
      # https://madaidans-insecurities.github.io/guides/linux-hardening.html#boot-kernel
      "slab_nomerge"
      "vsyscall=none"
      "debugfs=off"
      "page_alloc.shuffle=1"

      "mce=0" # even on servers, better to panic than get silent mem corruption
      "randomize_kstack_offset=on"
      "oops=panic" # TODO: make sure this doesn't break anything...

      "init_on_alloc=1"
      "init_on_free=1"

      # "module.sig_enforce=1"
      # "lockdown=confidentiality"

      "quiet"
      "loglevel=0"
    ];

    # blacklisted modules
    # https://github.com/NixOS/nixpkgs/blob/9e19e8fbb5b180404cc2b130c51d578e3b7ef998/nixos/modules/profiles/hardened.nix#L74-L102
    boot.blacklistedKernelModules = [
      # Obscure network protocols
      "ax25"
      "netrom"
      "rose"

      # Old or rare or insufficiently audited filesystems
      "adfs"
      "affs"
      "bfs"
      "befs"
      "cramfs"
      "efs"
      "erofs"
      "exofs"
      "freevxfs"
      "f2fs"
      "hfs"
      "hpfs"
      "jfs"
      "minix"
      "nilfs2"
      #"ntfs"
      "omfs"
      "qnx4"
      "qnx6"
      "sysv"
      "ufs"
    ];
  };
}
