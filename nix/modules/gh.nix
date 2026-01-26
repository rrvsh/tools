{
  config.flake = {
    modules.homeManager.rafiq =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.gh ];
      };
  };
}
