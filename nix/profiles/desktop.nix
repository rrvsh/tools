{ config, ... }:
let
  cfg = config.flake;
in
{
  config.flake.modules.darwin.profile-desktop = {
    imports = with cfg.modules.darwin; [
      firefox
      ghostty
    ];
  };
  config.flake.modules.nixos.profile-desktop = {
    imports = with cfg.modules.nixos; [
      waybar
      ghostty
      firefox
      hyprland
      audio-config
    ];
    time.timeZone = "Asia/Singapore";
    home-manager.sharedModules = [
      { services.hypridle.enable = true; }
    ];
  };
}
