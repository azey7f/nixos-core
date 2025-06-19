{
  config,
  lib,
  azLib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.az.core.programs;
in {
  options.az.core.programs = with azLib.opt; {
    enable = optBool false;
    excludedPackages = mkOption {
      type = with types; listOf package;
      default = [];
    };

    config = {
      btop.cudaSupport = optBool false;
      btop.rocmSupport = optBool false;
    };
  };

  config = mkIf cfg.enable {
    ### PROGRAMS ###
    programs = {
      fish.enable = true;
      fish.promptInit = "${pkgs.any-nix-shell}/bin/any-nix-shell fish --info-right | source";

      nano.enable = false; # ew
      neovim = {
        enable = true;
        defaultEditor = true;
        vimAlias = true;
        viAlias = true;
      };

      gnupg.agent = {
        enable = true;
        pinentryPackage = pkgs.pinentry-tty;
        enableSSHSupport = true;
      };

      git.enable = true;
    };
    users.users.root.shell = pkgs.fish;

    ### PACKAGES ###
    environment.systemPackages = with pkgs;
      lists.subtractLists cfg.excludedPackages [
        # security
        crowdsec

        # idiot-proofing
        molly-guard

        # essential
        fastfetch
        neofetch
        (btop.override {inherit (cfg.config.btop) cudaSupport rocmSupport;})
        wget
        anarchism
        kitty.terminfo
        any-nix-shell

        # misc tools
        iptables
        age
        du-dust
        nmap
        ldns
        sysstat
        sops
        openssl
        bridge-utils
        gptfdisk
        termshark
        rsync
        wget
        btrfs-progs
        p7zip
        zip
        unzip
        xz
        ripgrep
        jq
        iperf3
        ipcalc
        tree
        ltrace
        strace
        lsof
        usbutils
        pciutils
        torsocks
        hwloc
        q
        killall
        file
        moreutils #vidir
        highlight
        hdparm
        wireguard-tools
        gnupg
        nixpkgs-review
      ];
  };
}
