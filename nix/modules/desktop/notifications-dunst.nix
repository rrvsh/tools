{
  config.flake.modules.homeManager.rafiq =
    { pkgs, ... }:
    {
      services.dunst.enable = pkgs.stdenv.isLinux;
    };
}
