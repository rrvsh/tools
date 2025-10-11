{
  flake.modules.nixos.networking =
    { config, ... }:
    {
      services = {
        openssh.enable = true;
        tailscale = {
          enable = true;
          authKeyFile = config.sops.secrets."keys/tailscale".path;
        };
      };
      sops.secrets."keys/tailscale".sopsFile = ./keys.yaml;
    };
}
