{ inputs, ... }:
{
  config.flake.modules.nixos.sops-config =
    { config, primaryUser, ... }:
    {
      imports = [ inputs.sops-nix.nixosModules.sops ];
      sops.age.sshKeyPaths = [ "${config.users.users.${primaryUser.name}.home}/.ssh/id_ed25519" ];
    };
  config.flake.modules.darwin.sops-config =
    { config, primaryUser, ... }:
    {
      imports = [ inputs.sops-nix.darwinModules.sops ];
      sops.age.sshKeyPaths = [ "${config.users.users.${primaryUser.name}.home}/.ssh/id_ed25519" ];
    };
}
