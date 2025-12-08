{ inputs, lib, ... }:
let
  inherit (lib.strings) concatStrings;
in
{
  flake.modules = {
    darwin.rafiq =
      { pkgs, ... }:
      {
        system = {
          activationScripts.extraActivation.text = ''
            echo >&2 "ensuring rosetta is installed..."
            softwareupdate --install-rosetta --agree-to-license
            echo >&2 "configuring power management..."
            sudo pmset -a disablesleep 1
            sudo pmset -a displaysleep 0
          '';
          defaults.NSGlobalDomain."com.apple.swipescrolldirection" = false;
          keyboard.enableKeyMapping = true;
          keyboard.remapCapsLockToEscape = true;
        };
        homebrew.brews = [ "docker" ];
        home-manager.users.rafiq = {
          home.packages = [ pkgs.monitorcontrol ];
        };
      };
    homeManager.rafiq =
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
              directory.truncation_symbol = "../";
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
          neovim.plugins = with pkgs.vimPlugins; [
            fidget-nvim
            mini-nvim
            nvim-lspconfig
            plenary-nvim
            which-key-nvim
            yazi-nvim
          ];
          neovim.extraPackages = with pkgs; [
            cargo
            clippy
            lua-language-server
            nil
            pyright
            ruff
            rust-analyzer
            rustc
            rustfmt
            stylua
          ];
        };
      };
  };
}
