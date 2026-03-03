{
  config.flake = {
    allowedUnfreePackages = [
      "steam"
      "steam-original"
      "steam-run"
      "steam-unwrapped"
    ];
    modules.nixos.steam = {
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
  };
}
