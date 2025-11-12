# considerations: probably want the following structure for keybinds
# super -> within a window, new tab, copy, paste, etc
# leader keys -> within an app, e.g <leader>s to save
# alt ->
# ctrl ->
# super alt -> move a window?
# super ctrl -> workspaces?
# shift should be a modifier of other modifiers aka super shift t in firefox
{ inputs, ... }:
{
  flake = {
    allowedUnfreePackages = [ "slack" ];
    modules.darwin.rafiq =
      { pkgs, ... }:
      {
        homebrew.brews = [ "docker" ];
        home-manager.users.rafiq = {
          home.packages = with pkgs; [
            slack
            monitorcontrol
          ];
        };
      };
    modules.homeManager.rafiq =
      { pkgs, config, ... }:
      {
        imports = [ inputs.nix-index-database.homeModules.nix-index ];
        home = {
          packages = with pkgs; [ gh ];
          shellAliases = {
            cd = "z";
            nix-search = ''
              nix-locate -r '.' --minimal --all 2>/dev/null | \
              rga -v '^\([^)]*\)$' | \
              sk
            '';
            v = "$EDITOR";
            e = "fish -c 'set -e var; set var (sk); test -n \"$var\"; and $EDITOR $var'";
            t = config.programs.yazi.shellWrapperName;
            gaa = "git add";
            gap = "git add -p .";
            gc = "git commit";
            gcam = "git commit -am";
            gcamend = "git commit -a --amend --no-edit";
            gcend = "git commit --amend --no-edit";
            gcm = "git commit -m";
            gdb = "git rev-parse --abbrev-ref origin/HEAD | cut -d'/' -f2-";
            gd = "git diff";
            gdh = "git diff HEAD";
            gdm = "git diff $(gdb)";
            gds = "git diff --staged";
            grc = "git rebase --continue";
            gs = "git status";
            gu = "git push";
            gundo = "git add . && git stash && git reset HEAD~1 && git stash pop";
            gupdate = "git add . && git stash && git checkout $(gdb) && git pull && git checkout - && git rebase $(gdb) && git stash pop";
            gupdate-main = "git add . && git stash && git checkout $(gdb) && git pull && git checkout - && git stash pop";
          };
        };
        programs = {
          zoxide.enable = true;
          nix-index.enable = true;
          nix-index-database.comma.enable = true;
          mise.enable = true;
          skim.enable = true;
          skim.defaultCommand = "rga --files --hidden --glob '!.git'";
          ripgrep-all.enable = true;
          direnv.enable = true;
          direnv.nix-direnv.enable = true;
          nvf.settings.vim = {
            startPlugins = [ "snacks-nvim" ];
            extraPackages = with pkgs; [
              ruff
              ripgrep
            ];
            lsp = {
              enable = true;
              formatOnSave = true;
            };
            languages = {
              enableExtraDiagnostics = true;
              enableFormat = true;
              enableTreesitter = true;
              nix = {
                enable = true;
                format.type = "nixfmt";
                lsp.server = "nil";
              };
              python = {
                enable = true;
                format.type = "ruff";
                lsp.server = "pyright";
              };
            };
          };
        };
      };
  };
}
