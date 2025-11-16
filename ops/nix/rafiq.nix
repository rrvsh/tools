# considerations: probably want the following structure for keybinds
# super -> within a window, new tab, copy, paste, etc
# leader keys -> within an app, e.g <leader>s to save
# alt ->
# ctrl ->
# super alt -> move a window?
# super ctrl -> workspaces?
# shift should be a modifier of other modifiers aka super shift t in firefox
{ inputs, lib, ... }:
let
  inherit (lib.strings) concatStrings;
in
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
          starship = {
            enable = true;
            settings = {
              add_newline = false;
              format = concatStrings [
                # First Line Left
                "$hostname$directory$git_branch$git_status$git_state"
                # Fill First Line Space
                "$fill"
                # First Line Right
                "$nix_shell"
                "$time"
                # Line Break
                "\n"
                # Second Line Left
                "$battery$character"
              ];
              # Second Line Right
              right_format = "$git_metrics";
              git_status.format = "[$all_status$ahead_behind]($style)";
              git_metrics.format = "([-$deleted]($deleted_style) )([+$added]($added_style))";
              git_branch.format = "[$symbol$branch(:$remote_branch)]($style) ";
              git_metrics.disabled = false;
              time = {
                disabled = false;
                format = "[$time]($style)";
                time_format = "%R";
              };
              shlvl.disabled = false;
              username.disabled = true;
              fill.symbol = " ";
              python = {
                symbol = "";
                format = "[$symbol ]($style)";
                style = "yellow";
              };
            };
          };
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
            utility.yazi-nvim = {
              enable = true;
              setupOpts.open_for_directories = true;
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
