{ inputs, ... }:
let
  mkSopsConfig =
    sopsModule:
    {
      config,
      lib,
      primaryUser,
      ...
    }:
    {
      imports = lib.optional (primaryUser != null) sopsModule;
      config = lib.mkIf (primaryUser != null) {
        sops.age.sshKeyPaths = [ "${config.users.users.${primaryUser.name}.home}/.ssh/id_ed25519" ];
      };
    };
in
{
  config.flake.modules.nixos.sops-config = mkSopsConfig inputs.sops-nix.nixosModules.sops;
  config.flake.modules.darwin.sops-config = mkSopsConfig inputs.sops-nix.darwinModules.sops;
}
