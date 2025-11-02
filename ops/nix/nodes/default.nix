{ config, ... }:
let
  cfg = config.flake;
  inherit (cfg.paths) secrets;
in
{
  config.flake.modules.nixos.default =
    {
      hostName,
      config,
      ...
    }:
    {
      networking.hostName = hostName;
      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        substituters = [ "https://nix-community.cachix.org" ];
        trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
        trusted-substituters = [ "https://nix-community.cachix.org" ];
      };
      services = {
        openssh.enable = true;
        tailscale.enable = true;
        tailscale.authKeyFile = config.sops.secrets."keys/tailscale".path or null;
      };
      sops.secrets."keys/tailscale".sopsFile = secrets + /keys.yaml;
      system.stateVersion = "25.11";
    };
}
