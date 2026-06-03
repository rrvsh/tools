{ config, inputs, ... }:
let
  cfg = config.flake;
  inherit (cfg.paths) root;
  homeConfig =
    {
      config,
      pkgs,
      osConfig,
      lib,
      ...
    }:
    {
      home = {
        packages =
          with pkgs;
          (lib.lists.optional stdenv.isDarwin alt-tab-macos)
          ++ (lib.lists.optional stdenv.isDarwin monitorcontrol)
          ++ (lib.lists.optional stdenv.isLinux mixxx)
          ++ (lib.lists.optional stdenv.isLinux libnotify)
          ++ [
            ddgr
            gh
            ripgrep
          ];
        shellAliases = {
          cd = "echo \"Please use z\"";
          gparentbranch = "git rev-parse --abbrev-ref origin/HEAD | cut -d'/' -f2-";
          gc = "git commit";
          gcam = "git commit -am";
          quick-commit = "git add . && git commit -m \"$(date +'%Y-%m-%d %H:%M:%S')\" && git push";
          gcamend = "git commit -a --amend --no-edit";
          gcend = "git commit --amend --no-edit";
          gco = "git checkout";
          gcob = "git checkout -b";
          gd = "git diff";
          gdh = "git diff HEAD";
          gdm = "git diff $(gparentbranch)";
          gds = "git diff --staged";
          grc = "git rebase --continue";
          gs = "git status";
          gu = "git push";
          gy = "git pull";
          v = "$EDITOR";
          e = "fish -c 'set -e var; set var (sk); test -n \"$var\"; and $EDITOR $var'";
          t = config.programs.yazi.shellWrapperName;
          search = "ddgr -n 5 -C -x --np";
        };
      };
      programs = {
        wofi.enable = pkgs.stdenv.isLinux;
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
            python = {
              symbol = "";
              format = "[$symbol ]($style)";
              style = "yellow";
            };
          };
        };
        zoxide.enable = true;
        direnv = {
          enable = true;
          nix-direnv.enable = true;
        };
        mise.enable = true;
        skim = {
          enable = true;
          defaultCommand = "${lib.getExe pkgs.ripgrep} --files --hidden --glob '!.git'";
        };
        git = {
          enable = true;
          ignores = [ ".direnv/" ];
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
      };
      wayland.windowManager.hyprland = {
        enable = osConfig.programs.hyprland.enable or false;
        configType = "lua";
        package = null;
        portalPackage = null;
        extraConfig = ''
          hl.on("hyprland.start", function()
            hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE && ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE && systemctl --user restart waybar.service waybar-peek.service")
          end)
        '';
        settings = {
          monitor = [
            {
              output = "HDMI-A-1";
              mode = "3840x2160@160";
              position = "auto";
              scale = 2;
            }
            {
              output = "";
              mode = "preferred";
              position = "auto";
              scale = 2;
            }
          ];
          config = {
            input = {
              sensitivity = 1.0;
            };
            general = {
              gaps_in = 0;
              gaps_out = 0;
              border_size = 0;
            };
          };
          bind = [
            {
              _args = [
                "XF86AudioRaiseVolume"
                (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+\")")
                { repeating = true; }
              ];
            }
            {
              _args = [
                "XF86AudioLowerVolume"
                (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-\")")
                { repeating = true; }
              ];
            }
            {
              _args = [
                "XF86AudioMute"
                (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle\")")
              ];
            }
            {
              _args = [
                "XF86AudioMicMute"
                (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle\")")
              ];
            }
            {
              _args = [
                "ALT + SPACE"
                (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"wofi --show drun\")")
              ];
            }
            {
              _args = [
                "ALT + CTRL + 1"
                (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"ghostty\")")
              ];
            }
            {
              _args = [
                "ALT + CTRL + 2"
                (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"firefox\")")
              ];
            }
            {
              _args = [
                "ALT + CTRL + W"
                (lib.generators.mkLuaInline "hl.dsp.window.close()")
              ];
            }
            {
              _args = [
                "ALT + CTRL + P"
                (lib.generators.mkLuaInline "hl.dsp.window.float({ action = \"toggle\" })")
              ];
            }
            {
              _args = [
                "ALT + H"
                (lib.generators.mkLuaInline "hl.dsp.focus({ direction = \"left\" })")
              ];
            }
            {
              _args = [
                "ALT + J"
                (lib.generators.mkLuaInline "hl.dsp.focus({ direction = \"down\" })")
              ];
            }
            {
              _args = [
                "ALT + K"
                (lib.generators.mkLuaInline "hl.dsp.focus({ direction = \"up\" })")
              ];
            }
            {
              _args = [
                "ALT + L"
                (lib.generators.mkLuaInline "hl.dsp.focus({ direction = \"right\" })")
              ];
            }
            {
              _args = [
                "ALT + SUPER + H"
                (lib.generators.mkLuaInline "hl.dsp.focus({ workspace = \"r-1\" })")
              ];
            }
            {
              _args = [
                "ALT + SUPER + L"
                (lib.generators.mkLuaInline "hl.dsp.focus({ workspace = \"r+1\" })")
              ];
            }
            {
              _args = [
                "ALT + SHIFT + H"
                (lib.generators.mkLuaInline "hl.dsp.window.move( { direction = \"left\" })")
              ];
            }
            {
              _args = [
                "ALT + SHIFT + J"
                (lib.generators.mkLuaInline "hl.dsp.window.move( { direction = \"down\" })")
              ];
            }
            {
              _args = [
                "ALT + SHIFT + K"
                (lib.generators.mkLuaInline "hl.dsp.window.move( { direction = \"up\" })")
              ];
            }
            {
              _args = [
                "ALT + SHIFT + L"
                (lib.generators.mkLuaInline "hl.dsp.window.move( { direction = \"right\" })")
              ];
            }
            {
              _args = [
                "ALT + SHIFT + SUPER + H"
                (lib.generators.mkLuaInline "hl.dsp.window.move( { workspace = \"r-1\" })")
              ];
            }
            {
              _args = [
                "ALT + SHIFT + SUPER + L"
                (lib.generators.mkLuaInline "hl.dsp.window.move( { workspace = \"r+1\" })")
              ];
            }
            {
              _args = [
                "ALT + SHIFT + mouse:272"
                (lib.generators.mkLuaInline "hl.dsp.window.drag()")
                { mouse = true; }
              ];
            }
            {
              _args = [
                "ALT + SHIFT + mouse:273"
                (lib.generators.mkLuaInline "hl.dsp.window.resize()")
                { mouse = true; }
              ];
            }
          ];
        };
      };
      services.dunst.enable = pkgs.stdenv.isLinux;
      services.hypridle = lib.mkIf (pkgs.stdenv.isLinux && (osConfig.programs.hyprland.enable or false)) (
        let
          uid = toString osConfig.users.users.rafiq.uid;
          runtimeDir = "/run/user/${uid}";
          idleStateFile = "${runtimeDir}/hypridle-state";
        in
        {
          enable = true;
          settings = {
            listener = [
              {
                timeout = 60;
                on-timeout = "${pkgs.bash}/bin/bash -lc 'printf idle > \"${idleStateFile}\"'";
                on-resume = "${pkgs.bash}/bin/bash -lc 'printf active > \"${idleStateFile}\"'";
              }
            ];
          };
        }
      );
      targets.darwin.copyApps.enable = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (lib.mkForce false);
      assertions = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        {
          assertion =
            osConfig.programs.hyprland.portalPackage
            == inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
          message = "You must be using xdg-desktop-portal-hyprland for Pipewire screencapturing to work.";
        }
        {
          assertion = osConfig.services.pipewire.enable && osConfig.services.pipewire.wireplumber.enable;
          message = "You must enable pipewire and wireplumber for screencapturing to work.";
        }
      ];
    };
  sharedOsConfig =
    { config, pkgs, ... }:
    {
      sops.age.sshKeyPaths = [ "${config.users.users.rafiq.home}/.ssh/id_ed25519" ];
      nix.settings.trusted-users = [ "rafiq" ];
      users.users.rafiq.shell = pkgs.fish;
      home-manager.users.rafiq = {
        imports = [
          cfg.modules.homeManager.firefox
          cfg.modules.homeManager.ghostty
          cfg.modules.homeManager.neovim
          cfg.modules.homeManager.nix-index-comma
          cfg.modules.homeManager.pi-agent
          cfg.modules.homeManager.prismlauncher
          cfg.modules.homeManager.waybar
          cfg.modules.homeManager.yazi
          homeConfig
        ];
        home = {
          username = "rafiq";
          homeDirectory = config.users.users.rafiq.home;
          stateVersion = "26.05";
        };
      };
    };
in
{
  config.flake.modules.nixos.rafiq =
    { config, ... }:
    {
      imports = [
        sharedOsConfig
        cfg.modules.nixos.home-manager-config
      ];
      programs.fish.enable = true;
      users.mutableUsers = false;
      users.users.rafiq = {
        description = "Mohammad Rafiq";
        uid = 1000;
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n"
        ];
        hashedPasswordFile = config.sops.secrets."rafiq/password".path;
      };
      sops.secrets."rafiq/password" = {
        sopsFile = root + "/sops/rafiq.yaml";
        neededForUsers = true;
      };
    };
  config.flake.modules.darwin.rafiq = {
    imports = [
      sharedOsConfig
      cfg.modules.darwin.home-manager-config
    ];
    programs.fish.enable = true;
    system.primaryUser = "rafiq";
    users.knownUsers = [ "rafiq" ];
    users.users.rafiq = {
      home = "/Users/rafiq";
      uid = 501;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n"
      ];
    };
    homebrew.casks = [
      "ghostty"
      "mixxx"
    ];
  };
}
