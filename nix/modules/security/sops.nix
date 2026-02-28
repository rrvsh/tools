{ config, inputs, ... }:
let
  inherit (config.flake.accounts.rafiq) username;
in
{
  config.flake = {
    modules.nixos.default =
      { config, ... }:
      let
        homeDirectory = config.users.users.${username}.home;
      in
      {
        imports = [ inputs.sops-nix.nixosModules.sops ];
        sops.age.sshKeyPaths = [ "${homeDirectory}/.ssh/id_ed25519" ];
      };
    modules.darwin.default =
      { config, ... }:
      let
        homeDirectory = config.users.users.${username}.home;
      in
      {
        imports = [ inputs.sops-nix.darwinModules.sops ];
        sops.age.sshKeyPaths = [ "${homeDirectory}/.ssh/id_ed25519" ];
      };
  };
}
