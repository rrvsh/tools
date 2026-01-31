{ inputs, ... }:
{
  config.flake = {
    modules.nixos.default = {
      imports = [ inputs.sops-nix.nixosModules.sops ];
    };
    modules.darwin.default = {
      imports = [ inputs.sops-nix.darwinModules.sops ];
    };
  };
}
