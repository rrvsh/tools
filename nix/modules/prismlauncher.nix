{ inputs, ... }:
{
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
