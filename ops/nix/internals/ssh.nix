{
  flake.modules.nixos.default =
    { hostName, ... }:
    {
      networking.hostName = hostName;
      services.openssh.enable = true;
    };
}
