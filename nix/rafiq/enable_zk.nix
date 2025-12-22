{
  config.flake = {
    modules.homeManager.rafiq =
      { pkgs, ... }:
      {
        programs = {
          # needed for zk interactive finder
          fzf.enable = true;
          neovim.plugins = with pkgs.vimPlugins; [ zk-nvim ];
          zk = {
            enable = true;
            settings.notebook.dir = "$HOME/ref";
          };
        };
        home.sessionVariables.ZK_NOTEBOOK_DIR = "$HOME/ref";
        home.shellAliases = {
          # e.g. 10112025
          log = "zk edit $(date +%d%m%Y)-log";
          scratch = "zk edit $(date +%d%m%Y)-scratchpad";
          ref = "zk edit -i";
        };
      };
  };
}
