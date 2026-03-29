{ lib, ... }:
{
  config.flake.modules.homeManager.rafiq =
    { pkgs, ... }:
    {
      home.packages = lib.optional pkgs.stdenv.isLinux pkgs.mixxx;
    };
  config.flake.modules.darwin.rafiq = {
    homebrew.casks = [ "mixxx" ];
  };
}
