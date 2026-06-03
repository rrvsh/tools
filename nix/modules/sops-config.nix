{ inputs, ... }:
{
  config.flake.modules.nixos.sops-config =
    { config, ... }:
    {
      imports = [ inputs.sops-nix.nixosModules.sops ];
      sops.age.sshKeyPaths = [ "${config.users.users.rafiq.home}/.ssh/id_ed25519" ];
    };
  config.flake.modules.darwin.sops-config =
    { config, ... }:
    {
      imports = [ inputs.sops-nix.darwinModules.sops ];
      sops.age.sshKeyPaths = [ "${config.users.users.rafiq.home}/.ssh/id_ed25519" ];
    };
}
