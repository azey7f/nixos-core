{
  config,
  azLib,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.az.svc;
in {
  options.az.svc.ssh = with azLib.opt; {
    enable = optBool false;

    openFirewall = optBool false;
    ports = mkOption {
      type = with types; listOf port;
      default = [22];
    };

    keys = mkOption {
      type = with types; listOf singleLineStr;
      default = [];
    };
    passwordAuth = optBool false;
  };
  options.az.svc.endlessh.enable = azLib.opt.optBool false;

  config = {
    # sshd
    # TODO: harden properly
    services.openssh = mkIf cfg.ssh.enable {
      enable = true;
      openFirewall = cfg.ssh.openFirewall;
      ports = cfg.ssh.ports;
      settings = {
        PasswordAuthentication = cfg.ssh.passwordAuth;
        KbdInteractiveAuthentication = false;
      };
      extraConfig = ''
        TCPKeepAlive yes
        ClientAliveInterval 60
        ClientAliveCountMax 5
      '';
    };

    users.users.root.openssh.authorizedKeys.keys = cfg.ssh.keys;

    # endlessh
    services.endlessh-go.enable = cfg.endlessh.enable;
    services.endlessh-go.port = 22;
  };
}
