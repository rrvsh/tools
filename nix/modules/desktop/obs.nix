{ inputs, ... }:
{
  config.flake.modules.homeManager.rafiq =
    {
      pkgs,
      osConfig,
      lib,
      ...
    }:
    lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      assertions = [
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
      programs.obs-studio = {
        enable = true;
        package = pkgs.symlinkJoin {
          name = "obs-studio-wrapped";
          paths = [ pkgs.obs-studio ];
          buildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/obs \
              --set QT_QPA_PLATFORM xcb
          '';
        };
      };
    };
}
