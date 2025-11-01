# provide sops to the whole flake
{
  inputs,
  config,
  lib,
  ...
}:
let
  cfg = config.flake;
  inherit (cfg.paths) secrets;
  inherit (cfg.manifest.helpers) admin;
  inherit (lib.attrsets) mapAttrs';
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in
{
  options.flake.manifest.options.sops.enable = mkEnableOption "";
  config.flake.modules.nixos.default = mkIf cfg.manifest.options.sops.enable (
    { config, ... }:
    let
      inherit (config.users) defaultUserHome;
    in
    {
      imports = [ inputs.sops-nix.nixosModules.sops ];
      sops.age.sshKeyPaths = [ "${defaultUserHome}/${admin.username}/.ssh/id_ed25519" ];
      sops.secrets = mapAttrs' (name: _value: {
        name = "${name}/hashedPassword";
        value = {
          neededForUsers = true;
          sopsFile = secrets + /users.yaml;
        };
      }) cfg.manifest.users;
    }
  );
}
