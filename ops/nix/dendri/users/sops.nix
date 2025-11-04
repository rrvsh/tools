{
  inputs,
  config,
  lib,
  ...
}:
let
  cfg = config.flake;
  userSecrets = secrets + /users.yaml;
  inherit (cfg.paths) secrets;
  inherit (cfg.users) admin;
  inherit (builtins) pathExists;
  inherit (lib.attrsets) mapAttrs';
  inherit (lib.options) mkOption;
  inherit (lib.types) enum;
  inherit (lib.modules) mkIf;
in
{
  options.flake.users.secrets.type = mkOption {
    type = enum [ "sops" ];
    default = "sops";
  };
  config.flake.modules.nixos.leaf =
    { config, ... }:
    let
      sshKeyPath = "${config.users.users.${admin.username}.home}/.ssh/id_ed25519";
    in
    {
      imports = [ inputs.sops-nix.nixosModules.sops ];
      config = mkIf (cfg.users.secrets.type == "sops") {
        assertions = [
          {
            assertion = pathExists userSecrets;
            message = "You must have created ${userSecrets} to set user passwords.";
          }
        ];
        system.activationScripts.ensureSshKey.text = # bash
          ''
            path="${sshKeyPath}"
            if [ ! -f "$path" ]; then
              echo "Error: SSH key missing at $path"
              echo "Create or copy it before rebuilding."
              exit 1
            fi
          '';
        sops.age.sshKeyPaths = [ sshKeyPath ];
        sops.secrets = mapAttrs' (name: _value: {
          name = "${name}/hashedPassword";
          value = {
            neededForUsers = true;
            sopsFile = userSecrets;
          };
        }) cfg.users.users;
      };
    };
}
