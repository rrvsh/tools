{ inputs, ... }:
{
  config.flake.modules.homeManager.rafiq =
    { pkgs, ... }:
    {
      programs.yazi = {
        enable = true;
        shellWrapperName = "yy";
        package = inputs.yazi.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
          runtimeDeps = ps: ps ++ [ pkgs.exiftool ];
        };
        keymap = {
          mgr.prepend_keymap = [
            {
              on = [
                "c"
                "r"
              ];
              run = "plugin path-from-root";
              desc = "Copies path from git root";
            }
          ];
        };
      };
    };
}
