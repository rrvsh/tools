{
  flake.modules.nixos.default =
    { hostName, hostConfig, ... }:
    {
      nixpkgs.hostPlatform.system = "${hostConfig.arch}-linux";
      networking.hostName = hostName;
    };
}
