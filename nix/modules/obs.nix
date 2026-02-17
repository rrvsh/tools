{ inputs, ... }:
{
  config.flake.modules.homeManager.rafiq =
    { osConfig, pkgs, ... }:
    {
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
      programs.obs-studio.enable = true;
    };
}
