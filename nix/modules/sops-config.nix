{ inputs, ... }:
let
  mkSopsConfig =
    sopsModule:
    { config, primaryUser, ... }:
    {
      imports = [ sopsModule ];
      sops.age.sshKeyPaths = [ "${config.users.users.${primaryUser.name}.home}/.ssh/id_ed25519" ];
    };
in
{
  config.flake.modules.nixos.sops-config = mkSopsConfig inputs.sops-nix.nixosModules.sops;
  config.flake.modules.darwin.sops-config = mkSopsConfig inputs.sops-nix.darwinModules.sops;
}
