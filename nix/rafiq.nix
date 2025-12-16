{
  inputs,
  lib,
  config,
  ...
}:
let
  cfg = config.flake;
  inherit (cfg.paths) root;
  inherit (lib.strings) concatStrings;
  inherit (lib.lists) optionals;
in
{
  config.flake = {
    users.users.rafiq = {
      primary = true;
      email = "rafiq@rrv.sh";
      pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n";
    };
    modules = {
      darwin.rafiq = {
        system.activationScripts.extraActivation.text = ''
          echo >&2 "configuring power management..."
          sudo pmset -a disablesleep 1
          sudo pmset -a displaysleep 0
        '';
        system.defaults.NSGlobalDomain."com.apple.swipescrolldirection" = false;
        system.keyboard.enableKeyMapping = true;
        system.keyboard.remapCapsLockToEscape = true;

        homebrew.brews = [ "docker" ];
        homebrew.casks = [ "ghostty" ];
      };
      homeManager.rafiq =
        { pkgs, ... }:
        {
          imports = [
            inputs.nvf.homeManagerModules.default
            inputs.nix-index-database.homeModules.nix-index
          ];
          xdg.configFile."nvim/lua".source = root + /src/lua;

          home.packages =
            with pkgs;
            [ gh ]
            ++ optionals pkgs.stdenv.isDarwin [
              alt-tab-macos
              monitorcontrol
            ];

          # e.g. 10112025.md
          home.shellAliases."in" = "mkdir -p ~/in && $EDITOR ~/in/$(date +%d%m%Y).md";
          home.shellAliases.cd = "z";
          home.shellAliases.nix-search = ''
            nix-locate -r '.' --minimal --all 2>/dev/null | \
            rga -v '^\([^)]*\)$' | \
            sk
          '';
          home.shellAliases.v = "$EDITOR";
          home.shellAliases.e = "fish -c 'set -e var; set var (sk); test -n \"$var\"; and $EDITOR $var'";
          home.shellAliases.gaa = "git add";
          home.shellAliases.gap = "git add -p .";
          home.shellAliases.gc = "git commit";
          home.shellAliases.gcam = "git commit -am";
          home.shellAliases.gcamend = "git commit -a --amend --no-edit";
          home.shellAliases.gcend = "git commit --amend --no-edit";
          home.shellAliases.gcm = "git commit -m";
          home.shellAliases.gdb = "git rev-parse --abbrev-ref origin/HEAD | cut -d'/' -f2-";
          home.shellAliases.gd = "git diff";
          home.shellAliases.gdh = "git diff HEAD";
          home.shellAliases.gdm = "git diff $(gdb)";
          home.shellAliases.gds = "git diff --staged";
          home.shellAliases.grc = "git rebase --continue";
          home.shellAliases.gs = "git status";
          home.shellAliases.gu = "git push";
          home.shellAliases.gundo = "git add . && git stash && git reset HEAD~1 && git stash pop";
          home.shellAliases.gupdate = "git add . && git stash && git checkout $(gdb) && git pull && git checkout - && git rebase $(gdb) && git stash pop";
          home.shellAliases.gupdate-main = "git add . && git stash && git checkout $(gdb) && git pull && git checkout - && git stash pop";

          programs.ghostty = {
            enable = true;
            package = if pkgs.stdenv.isDarwin then null else pkgs.ghostty; # ghostty broken on darwin
          };
          programs.git = {
            enable = true;
            signing = {
              signByDefault = true;
              key = "~/.ssh/id_ed25519.pub";
            };
            settings = {
              user.name = "Mohammad Rafiq";
              user.email = "rafiq@rrv.sh";
              gpg.format = "ssh";
              init.defaultBranch = "prime";
              push.autoSetupRemote = true;
            };
          };
          programs.codex = {
            enable = true;
            settings = {
              features.web_search_request = true;
              model = "gpt-5.1-codex-max"; # Little blurb to get it to use a temporary better model
              notice."hide_gpt-5.1-codex-max_migration_prompt" = true; # ^
              projects = {
                "/Users/rafiq".trust_level = "untrusted";
                "/Users/rafiq/repos".trust_level = "trusted";
                # "/Users/rafiq/repos/alphastory".trust_level = "trusted";
                # "/Users/rafiq/repos/pinbreak".trust_level = "trusted";
                # "/Users/rafiq/Downloads".trust_level = "untrusted";
              };
            };
            # Note: Don't remove or modify the following without STRICT research.
            custom-instructions = ''
              I should really remember that I have access to web search, and I should really try and use web search for anything that might be outdated or underrepresented in our dataset, which if the user is asking me, is probably true. I should verify syntax by reading language docs, confirm options by reading api references, and keep in mind the whole context by investigating and keeping in context our own codebase.
            '';
          };
          programs.carapace.enable = true;
          programs.zoxide.enable = true;
          programs.nix-index.enable = true;
          programs.nix-index-database.comma.enable = true;
          programs.mise.enable = true;
          programs.skim.enable = true;
          programs.skim.defaultCommand = "rga --files --hidden --glob '!.git'";
          programs.ripgrep-all.enable = true;
          programs.direnv.enable = true;
          programs.direnv.nix-direnv.enable = true;
          programs.starship = {
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
          programs.neovim = {
            enable = true;
            package = inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.default;
            defaultEditor = true;
            viAlias = true;
            vimAlias = true;
            extraLuaConfig = "require(\"rafiq\")";
            plugins = with pkgs.vimPlugins; [
              fidget-nvim
              mini-nvim
              nvim-lspconfig
              plenary-nvim
              which-key-nvim
              yazi-nvim
            ];
            extraPackages = with pkgs; [
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
  };
}
