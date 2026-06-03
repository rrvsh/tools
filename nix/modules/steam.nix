{
  config.flake.modules.nixos.steam =
    { lib, ... }:
    {
      nixpkgs.config.allowUnfreePredicate = lib.mkForce (
        pkg:
        builtins.elem (lib.strings.getName pkg) [
          "nvidia-kernel-modules"
          "nvidia-persistenced"
          "nvidia-settings"
          "nvidia-x11"
          "steam"
          "steam-original"
          "steam-run"
          "steam-unwrapped"
        ]
      );
      programs = {
        steam = {
          enable = true;
          remotePlay.openFirewall = true;
          dedicatedServer.openFirewall = true;
          localNetworkGameTransfers.openFirewall = true;
        };
        gamemode.enable = true;
        gamescope.enable = true;
      };
    };
}
