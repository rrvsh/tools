{ inputs, ... }:
{
  config.flake = {
    modules.darwin.rafiq = {
      nix.settings.extra-substituters = [ "https://yazi.cachix.org" ];
      nix.settings.extra-trusted-public-keys = [
        "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
      ];
    };
    modules.homeManager.rafiq =
      { config, pkgs, ... }:
      let
        path-from-root = pkgs.stdenv.mkDerivation {
          pname = "path-from-root";
          version = "unstable-2024-01-01";
          src = inputs.path-from-root-yazi;
          installPhase = ''
            mkdir -p $out
            cp -r . $out/
            mv $out/main.lua $out/init.lua
          '';
        };
      in
      {
        home.shellAliases.t = config.programs.yazi.shellWrapperName;
        programs.yazi = {
          enable = true;
          # this will use the binary cache configured above
          # but only after it is registered i.e. after a system rebuild is done with the above and **without this**
          # so comment this package out the first time you rebuild, then uncomment it and rebuild again
          package = inputs.yazi.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
            runtimeDeps = ps: ps ++ [ pkgs.exiftool ];
          };
          plugins = {
            "path-from-root" = path-from-root;
          };
          keymap = {
            manager.prepend_keymap = [
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
  };
}
