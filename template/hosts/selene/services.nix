{
  lib,
  config,
  ...
}: {
  services.fprintd.enable = true;

  /*
  # note: fn + left/right arrow does the same thing
  services.keyd = {
    enable = true;
    keyboards.internal = {
      ids = ["0001:0001:70533846"];
      settings = {
        main.media = "home";
        shift.media = "end";
      };
    };
  };
  */
}
