{ inputs, ... }:
{
  config.flake.modules.darwin.yazi = {
    nix.settings.extra-substituters = [ "https://yazi.cachix.org" ];
    nix.settings.extra-trusted-public-keys = [
      "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
    ];
  };
  config.flake.modules.homeManager.yazi =
    { pkgs, ... }:
    {
      programs.yazi = {
        enable = true;
        shellWrapperName = "yy";
        package = inputs.yazi.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
          runtimeDeps = ps: ps ++ [ pkgs.exiftool ];
        };
        plugins."path-from-root" = pkgs.stdenv.mkDerivation {
          pname = "path-from-root";
          version = "unstable-2024-01-01";
          src = inputs.path-from-root-yazi;
          installPhase = ''
            mkdir -p $out
            cp -r . $out/
          '';
        };
        keymap.mgr.prepend_keymap = [
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
}
