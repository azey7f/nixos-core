{
  config,
  azLib,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.az.svc.cron;
in {
  options.az.svc.cron = with azLib.opt; {
    enable = optBool false;
    mailto = optStr "root";
    jobs = with types; mkOpt (listOf str) [];
  };

  config = mkIf cfg.enable {
    services.cron = {
      inherit (cfg) enable mailto;
      systemCronJobs = cfg.jobs;
    };
  };
}
