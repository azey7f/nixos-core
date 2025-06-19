{
  lib,
  config,
  ...
}: {
  config = lib.mkIf config.az.core.home.enable {
    home-manager.users =
      lib.attrsets.mapAttrs (name: _: {
        programs.btop = {
          enable = true;
          settings = {
            color_theme = "dracula";
            theme_background = false;
            truecolor = true;

            vim_keys = true;

            proc_filter_kernel = true;
            update_ms = 500;
            shown_boxes = "cpu gpu0 proc mem net";
          };
        };
      })
      (config.az.core.users // {root = {};});
  };
}
