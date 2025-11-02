{ inputs, ... }:
{
  flake.modules.nixos.default =
    { hostConfig, ... }:
    {
      imports = [ inputs.nixos-facter-modules.nixosModules.facter ];
      facter.reportPath = hostConfig.facter or null;
    };
}
