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
        };
      };
  };
}
