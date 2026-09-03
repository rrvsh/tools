{ config, ... }:
let
  cfg = config.flake;
in
{
  config.flake.modules = {
    darwin.profile-development = {
      imports = with cfg.modules.darwin; [
        beads
        passwordless-sudo
        sops-config
        syncthing
        tailscale-config
        neovim
        nix-index-comma
        pi-agent
        yazi
      ];
      home-manager.sharedModules = [
        cfg.modules.homeManager.profile-development
        (
          { config, ... }:
          {
            launchd.agents.ssh-add = {
              enable = true;
              config = {
                ProgramArguments = [
                  "/bin/sh"
                  "-c"
                  "ssh-add ${config.home.homeDirectory}/.ssh/id_ed25519"
                ];
                RunAtLoad = true;
                KeepAlive = false;
              };
            };
          }
        )
      ];
    };
    nixos.profile-development = {
      imports = with cfg.modules.nixos; [
        beads
        passwordless-sudo
        sops-config
        syncthing
        tailscale-config
        neovim
        nix-index-comma
        pi-agent
        yazi
      ];
      networking.networkmanager.enable = true;
      programs.ssh.startAgent = true;
      home-manager.sharedModules = [
        cfg.modules.homeManager.profile-development
        (
          { pkgs, config, ... }:
          {
            systemd.user.services.ssh-add = {
              Unit = {
                Description = "Add SSH key to agent on login";
                Wants = [ "ssh-agent.service" ];
                After = [ "ssh-agent.service" ];
              };
              Service = {
                Type = "oneshot";
                Environment = "SSH_AUTH_SOCK=%t/ssh-agent";
                ExecStart = "${pkgs.openssh}/bin/ssh-add ${config.home.homeDirectory}/.ssh/id_ed25519";
                RemainAfterExit = true;
              };
              Install.WantedBy = [ "default.target" ];
            };
          }
        )
      ];
    };
    homeManager.profile-development =
      {
        config,
        hostName,
        lib,
        pkgs,
        ...
      }:
      let
        syncthingDevices = {
          alpha = {
            id = "SWMTPZZ-NIU7DVO-W6D5TNN-5ET4XCC-D3CE2JF-KNABVQO-MTW37ZD-TUD4SQZ";
            addresses = [ "tcp://100.103.246.12:22000" ];
          };
          mercury = {
            id = "AXYVAEZ-LWIJDVN-6C2YABB-GI3M3QS-E6ZSI4D-ZBCYWD5-CD5MPS5-H2ZBAQG";
            addresses = [ "tcp://100.127.209.56:22000" ];
          };
          nemesis = {
            id = "4WDU7B4-WFIUQXA-AQZ5ZXH-XAJ5F22-RZ6OQGO-NJVCMV3-I3BRRHW-XG4PXQM";
            addresses = [ "tcp://100.98.114.23:22000" ];
          };
        };
        remoteSyncthingDevices = lib.filterAttrs (name: _: name != hostName) syncthingDevices;
        artifactExtensions = [
          "csv"
          "html"
          "json"
          "log"
          "md"
          "svg"
          "toml"
          "txt"
          "xml"
          "yaml"
          "yml"
        ];
        agentsIgnorePatterns = [
          "/.session-drain/"
          "/.session-drain/**"
          "**/.cargo-home/"
          "**/.cargo-home/**"
          "**/.venv/"
          "**/.venv/**"
          "**/node_modules/"
          "**/node_modules/**"
          "**/target/"
          "**/target/**"
          "/research/lumen/"
          "/research/lumen/**"
          "/artifacts/sessions/"
          "/artifacts/sessions/**"
          "/artifacts/tachyon-codex-static-spike*.html"
          "/artifacts/codex-device-helper*"
          "!/artifacts/"
          "!/artifacts/**/"
        ]
        ++ lib.concatMap (extension: [
          "!/artifacts/*.${extension}"
          "!/artifacts/**/*.${extension}"
        ]) artifactExtensions
        ++ [ "/artifacts/**" ];
      in
      {
        home = {
          activation.agentsStignore = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            run rm -f ${config.home.homeDirectory}/Agents/.stignore
            run ${pkgs.coreutils}/bin/install -Dm0644 ${
              pkgs.writeText "agents-stignore" (lib.concatStringsSep "\n" agentsIgnorePatterns + "\n")
            } ${config.home.homeDirectory}/Agents/.stignore
          '';
          packages = with pkgs; [
            ddgr
            gh
            git-lfs
            ripgrep
          ];
          shellAliases = {
            cd = "echo \"Please use z\"";
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
            gu = "git push";
            gy = "git pull";
            v = "$EDITOR";
            e = "fish -c 'set -e var; set var (sk); test -n \"$var\"; and $EDITOR $var'";
          };
        };
        services.syncthing.settings = {
          devices = remoteSyncthingDevices;
          folders.agents = {
            path = "${config.home.homeDirectory}/Agents";
            id = "agents";
            label = "Agents";
            type = "sendreceive";
            devices = builtins.attrNames remoteSyncthingDevices;
            maxConflicts = 20;
            versioning = {
              type = "staggered";
              params = {
                cleanInterval = "3600";
                maxAge = "2592000";
              };
            };
          };
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
                "$hostname$directory$git_branch$git_status$git_state"
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
