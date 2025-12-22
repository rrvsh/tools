{
  config.flake = {
    modules.homeManager.rafiq = {
      # needed for zk interactive finder
      programs.fzf.enable = true;
      programs.zk.enable = true;
    };
  };
}
