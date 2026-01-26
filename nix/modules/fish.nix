{
  config.flake = {
    modules.homeManager.rafiq = {
      programs.fish.enable = true;
    };
    modules.darwin.rafiq =
      { pkgs, ... }:
      {
        users.users.rafiq.shell = pkgs.fish;
        programs.fish.enable = true;
      };
  };
}
