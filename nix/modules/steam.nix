{
  config.flake.allowedUnfreePackages = [
    "steam"
    "steam-original"
    "steam-run"
    "steam-unwrapped"
  ];
  config.flake.modules.nixos.steam = {
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
