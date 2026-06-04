{ inputs, config, ... }:
let
  cfg = config.flake;
in
{
  config.flake.modules.darwin.prismlauncher = {
    home-manager.sharedModules = [ cfg.modules.homeManager.prismlauncher ];
  };
  config.flake.modules.nixos.prismlauncher = {
    home-manager.sharedModules = [ cfg.modules.homeManager.prismlauncher ];
  };
  config.flake.modules.homeManager.prismlauncher =
    { pkgs, ... }:
    {
      home.packages = [
        (inputs.prismlauncher-cracked.packages.${pkgs.stdenv.hostPlatform.system}.prismlauncher.override {
          jdks = [ pkgs.jdk25 ];
        })
      ];
    };
}
