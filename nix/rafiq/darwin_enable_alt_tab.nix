{
  config.flake = {
    modules.homeManager.rafiq =
      { pkgs, ... }:
      {
        home.packages = pkgs.lib.lists.optional pkgs.stdenv.isDarwin pkgs.alt-tab-macos;
      };
  };
}
