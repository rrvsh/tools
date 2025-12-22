{
  config.flake = {
    modules.homeManager.rafiq = {
      programs.fzf = {
        # needed for zk interactive finder
        enable = true;
      };
      programs.zk = {
        enable = true;
        settings.notebook.dir = "~/ref";
      };
      home.shellAliases = {
        # e.g. 10112025
        log = "zk edit $(date +%d%m%Y)-log";
        scratch = "zk edit $(date +%d%m%Y)-scratchpad";
        ref = "zk edit -i";
      };
    };
  };
}
