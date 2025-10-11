{
  flake.modules.nixos.default =
    { hostName, ... }:
    {
      networking.hostName = hostName;
    };
}
