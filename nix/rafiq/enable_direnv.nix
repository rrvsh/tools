{
  config.flake.modules.homeManager.rafiq = {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
