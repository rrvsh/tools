{ inputs, ... }:
{
  flake.modules.nixos.secrets = {
    imports = [ inputs.sops-nix.nixosModules.sops ];
    #FIXME: Don't hardcode the home path
    config.sops.age.sshKeyPaths = [ "/home/rafiq/.ssh/id_ed25519" ];
  };
}
