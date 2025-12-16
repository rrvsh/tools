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
    allowedUnfreePackages = [ "firefox-bin" ];
    modules = {
      darwin.rafiq =
        { pkgs, ... }:
        {
          users.users.rafiq.shell = pkgs.fish;
          programs.fish.enable = true;
          # macOS upstream Firefox in nixpkgs is broken; this overlay provides the working firefox-bin build for Darwin.
          nixpkgs.overlays = [ inputs.nixpkgs-firefox-darwin.overlay ];
          nix.settings.extra-substituters = [ "https://yazi.cachix.org" ];
          nix.settings.extra-trusted-public-keys = [
            "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
          ];
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
          homebrew.casks = [ "ghostty" ];
        };
      homeManager.rafiq =
        { pkgs, config, ... }:
        {
          imports = [
            inputs.nvf.homeManagerModules.default
            inputs.nix-index-database.homeModules.nix-index
          ];
          xdg.configFile."nvim/lua".source = root + /src/lua;
          home = {
            packages =
              with pkgs;
              [ gh ]
              ++ optionals pkgs.stdenv.isDarwin [
                alt-tab-macos
                firefox-bin
                monitorcontrol
              ];
            shellAliases = {
              # e.g. 10112025.md
              "in" = "mkdir -p ~/in && $EDITOR ~/in/$(date +%d%m%Y).md";
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
            fish.enable = true;
            ghostty = {
              enable = true;
              package = if pkgs.stdenv.isDarwin then null else pkgs.ghostty; # ghostty broken on darwin
            };
            yazi = {
              enable = true;
              package = inputs.yazi.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
                # this will use the binary cache configured above
                # but only after it is registered i.e. after a system rebuild is done with the above and **without this**
                # so comment this package out the first time you rebuild, then uncomment it and rebuild again
                runtimeDeps = ps: ps ++ [ pkgs.exiftool ];
              };
            };
            firefox = {
              enable = true;
              # HM’s firefox module errors on Darwin when a package is set; keep null on macOS and install via home.packages.
              package = if pkgs.stdenv.isDarwin then null else pkgs.firefox;
            };
            git = {
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
            codex = {
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
            carapace.enable = true;
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
            neovim = {
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
  };
}
