{ config, lib, ... }:
let
  cfg = config.flake;
in
{
  config.flake.modules = {
    darwin.profile-development = {
      imports = with cfg.modules.darwin; [
        passwordless-sudo
        sops-config
        tailscale-config
        neovim
        nix-index-comma
        pi-agent
        yazi
      ];
      home-manager.sharedModules = [ cfg.modules.homeManager.profile-development ];
    };
    nixos.profile-development = {
      imports = with cfg.modules.nixos; [
        passwordless-sudo
        sops-config
        tailscale-config
        neovim
        nix-index-comma
        pi-agent
        yazi
      ];
      networking.networkmanager.enable = true;
      home-manager.sharedModules = [ cfg.modules.homeManager.profile-development ];
    };
    homeManager.profile-development =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          git-bug
          ddgr
          gh
          ripgrep
        ];
        home.shellAliases = {
          cd = "echo \"Please use z\"";
          gb = "git-bug termui";
          gc = "git commit";
          gcam = "git commit -am";
          gcamend = "git commit -a --amend --no-edit";
          gcend = "git commit --amend --no-edit";
          gco = "git checkout";
          gd = "git diff";
          gdh = "git diff HEAD";
          gdm = "git diff $(git rev-parse --abbrev-ref origin/HEAD | cut -d'/' -f2-)";
          gds = "git diff --staged";
          grc = "git rebase --continue";
          gs = "git status";
          gu = "git push && git-bug push";
          v = "$EDITOR";
          e = "fish -c 'set -e var; set var (sk); test -n \"$var\"; and $EDITOR $var'";
        };
        programs = {
          fish = {
            enable = true;
            interactiveShellInit = ''
              bind \cg 'commandline -r "git add ."; commandline -f execute'
            '';
          };
          tmux.enable = true;
          starship = {
            enable = true;
            settings = {
              add_newline = false;
              format = lib.strings.concatStrings [
                "$hostname$directory$git_branch$git_status$git_state\${custom.git-bug}"
                "$fill"
                "$nix_shell"
                "$time"
                "\n"
                "$battery$character"
              ];
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
              custom.git-bug = {
                when = ''
                  git for-each-ref --count=1 refs/bugs/ > /dev/null 2>&1 || exit 1
                  l=$(git for-each-ref refs/bugs/ --format="%(objectname) %(refname:lstrip=2)" 2>/dev/null | sort)
                  r=$(git for-each-ref refs/remotes/origin/bugs/ --format="%(objectname) %(refname:lstrip=4)" 2>/dev/null | sort)
                  [ "$l" != "$r" ]
                '';
                command = "true";
                format = "[ 🐛]($style)";
                shell = [ "${lib.getExe pkgs.bash}" ];
              };
            };
          };
          zoxide.enable = true;
          direnv.enable = true;
          direnv.nix-direnv.enable = true;
          mise.enable = true;
          skim = {
            enable = true;
            defaultCommand = "${lib.getExe pkgs.ripgrep} --files --hidden --glob '!.git'";
          };
          git = {
            enable = true;
            ignores = [ ".direnv/" ];
            includes = [ { path = "~/.gitconfig-override"; } ];
            signing = {
              signByDefault = true;
              key = "~/.ssh/id_ed25519.pub";
            };
            settings = {
              gpg.format = "ssh";
              push.autoSetupRemote = true;
            };
          };
        };
      };
  };
}
