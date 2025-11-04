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

    allowSysrq = optBool false;
    allowKexec = optBool false;
    forcePTI = optBool false; # +sec, -perf: https://en.wikipedia.org/wiki/Kernel_page-table_isolation#Implementation

    malloc = optStr "graphene-hardened-light";
    virtFlushCache = optStr "always";

    kernelLockdown = optBool true;
    lockKmodules = optBool true;
    enabledModules = mkOption {
      type = with types; listOf str;
      default = [];
    };

    disableWrappers = optBool true;
    enabledWrappers = mkOption {
      type = with types; listOf str;
      default = [];
    };
    extraDisabledWrappers = mkOption {
      type = with types; listOf str;
      default = [];
    };
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
    security.sudo = {
      enable = lib.mkDefault false;
      execWheelOnly = true;
      extraConfig = "Defaults lecture=never"; # not hardening but this is a nice place for it
    };
    az.core.hardening.enabledWrappers = lib.optional config.security.sudo.enable "sudo";

    networking.firewall = {
      enable = true; # TODO: nftables by default?
      allowPing = mkDefault cfg.allowPing;
    };

    # kernel stuff
    boot.kernelPackages = pkgs.linuxKernel.packages.linux_hardened;

    security.lockKernelModules = cfg.lockKmodules;
    security.protectKernelImage = !cfg.allowKexec;
    security.virtualisation.flushL1DataCache = cfg.virtFlushCache;
    security.forcePageTableIsolation = cfg.forcePTI;

    security.allowUserNamespaces = true; # necessary for nix.settings.sandbox
    security.unprivilegedUsernsClone = false;
    services.logrotate.checkConfig = false; # FIXME: https://github.com/NixOS/nixpkgs/issues/287194

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
        "kernel.sysrq" = cfg.allowSysrq;
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
        "kernel.core_pattern" = "|${pkgs.coreutils}/bin/false";
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

    boot.kernelParams =
      [
        "random.trust_cpu=off" # might as well

        # https://tails.net/contribute/design/kernel_hardening/
        # https://madaidans-insecurities.github.io/guides/linux-hardening.html#boot-kernel
        "slab_nomerge"
        "vsyscall=none"
        "debugfs=off"
        "page_alloc.shuffle=1"

        "mce=0" # even on servers, better to panic than get silent mem corruption
        "randomize_kstack_offset=on"
        "oops=panic" # NOTE: might break stuff, but haven't encountered any issues so far

        "init_on_alloc=1"
        "init_on_free=1"

        "quiet"
        "loglevel=0"
      ]
      ++ lib.optionals cfg.kernelLockdown [
        # NOTE: breaks some modules, maybe?
        # so far everything works fine though
        "module.sig_enforce=1"
        "lockdown=confidentiality"
      ];

    # blacklisted modules
    # https://github.com/NixOS/nixpkgs/blob/9e19e8fbb5b180404cc2b130c51d578e3b7ef998/nixos/modules/profiles/hardened.nix#L74-L102
    boot.blacklistedKernelModules = lib.lists.subtractLists cfg.enabledModules [
      # obscure network protocols
      "ax25"
      "netrom"
      "rose"

      # old, rare or insufficiently audited filesystems
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
      "ntfs"
      "omfs"
      "qnx4"
      "qnx6"
      "sysv"
      "ufs"
    ];

    # disable as many setuid wrappers as possible
    security.wrappers = lib.mkIf cfg.disableWrappers (
      builtins.listToAttrs (builtins.map (name: {
          inherit name;
          value.enable = lib.mkForce false;
        }) (lib.lists.subtractLists cfg.enabledWrappers ([
            # would've mapped config.security.wrappers directly, but that causes inf recursion :<
            # but hey, at least this way everything is commented

            # seems to be pretty important, but so far everything's working fine, so...
            # TODO: test w/ KDE on desktops
            "dbus-daemon-launch-helper"

            # FUSE, breakage can maybe(?) be circumvented by running stuff like sshfs as root
            # TODO: verify not having suid on fusermount{,3} is actually fine
            "fusermount"
            "fusermount3"

            # seems to just be a more fine-grained sudo alternative, shouldn't cause breakage
            "pkexec"

            # so far seems to be working fine?
            # TODO: suid shouldn't be necessary at all in next polkit release, notify nixpkgs
            # see https://github.com/polkit-org/polkit/pull/501
            "polkit-agent-helper-1"

            # mostly unused, but NOTE: newgidmap/newuidmap is necessary for running containers
            "sg"
            "newgrp"
            "newgidmap"
            "newuidmap"

            # can be replaced with sudo -i if actually needed
            "su"
            # sudoedit isn't really necessary for systems with a single physical user (me!)
            "sudoedit"

            # afaict only the `users` fstab mount option uses suid, not needed
            "umount"
            "mount"

            # sshd works without this provided UsePAM = no & /etc/shadow passwd is set to *
            # disabling it also makes any passwd-based login impossible system-wide
            "unix_chkpwd"
          ]
          ++ cfg.extraDisabledWrappers)))
    );
    security.enableWrappers = !(cfg.disableWrappers && 0 == (builtins.length cfg.enabledWrappers));

    az.svc.ssh = lib.mkIf (!(builtins.elem "unix_chkpwd" cfg.enabledWrappers)) {
      # SSH needs unix_chpwd for PAM
      usePAM = false;
    };
  };
}
