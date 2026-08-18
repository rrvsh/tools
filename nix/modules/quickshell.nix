{ config, ... }:
let
  cfg = config.flake;
in
{
  config.flake.modules = {
    nixos.quickshell =
      { pkgs, ... }:
      {
        home-manager.sharedModules = [ cfg.modules.homeManager.quickshell ];
        fonts.packages = [ pkgs.monocraft ];
      };
    homeManager.quickshell =
      { lib, pkgs, ... }:
      let
        inherit (pkgs) quickshell;
        shellConfig = pkgs.runCommand "nemesis-shell-config" { } ''
          cp -r ${../../quickshell/nemesis-shell} "$out"
          chmod -R u+w "$out"
          substituteInPlace "$out/BarHost.qml" \
            --replace-fail "@systemctl@" "${lib.getExe' pkgs.systemd "systemctl"}"
        '';
      in
      {
        programs.quickshell = {
          enable = true;
          package = quickshell;
          configs.nemesis-shell = shellConfig;
          activeConfig = "nemesis-shell";
          systemd = {
            enable = true;
            target = "hyprland-session.target";
          };
        };
        xdg.desktopEntries."org.quickshell" = {
          name = "Nemesis Shell";
          exec = "${lib.getExe quickshell} --config nemesis-shell";
          noDisplay = true;
        };
        systemd.user.services.quickshell = {
          Unit = {
            PartOf = [ "hyprland-session.target" ];
            StartLimitIntervalSec = 300;
            StartLimitBurst = 5;
            X-Restart-Triggers = [ shellConfig ];
          };
          Service = {
            Environment = [
              "QS_DISABLE_CRASH_HANDLER=1"
              "QS_DISABLE_FILE_WATCHER=1"
              "QS_NO_RELOAD_POPUP=1"
            ];
            RestartSec = 5;
            TimeoutStopSec = 10;
          };
        };
      };
  };
}
