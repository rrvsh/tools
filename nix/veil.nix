{ config, ... }:
let
  cfg = config.flake;
in
{
  flake = {
    manifest.hosts.nixos.veil = {
      arch = "aarch64";
      createImage = true;
      modules = with cfg.modules.nixos; [
        reverse-proxy
        rrv-sh
      ];
    };
    modules.nixos.veil =
      { pkgs, config, ... }:
      {
        nixpkgs.hostPlatform.system = "aarch64-linux";
        services = {
          openssh.enable = true;
          tailscale = {
            enable = true;
            authKeyFile = config.sops.secrets."keys/tailscale".path;
          };
        };
          sops.secrets."keys/tailscale".sopsFile = ./keys.yaml;
      };
  };
}
