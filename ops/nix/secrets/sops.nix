{
  inputs,
  config,
  lib,
  ...
}:
let
  cfg = config.flake;
  sopsFilePath = secrets + /users.yaml;
  inherit (cfg.paths) secrets;
  inherit (cfg.users) admin;
  inherit (builtins) hasAttr pathExists;
  inherit (lib.attrsets) mapAttrs';
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in
{
  options.flake.secrets.sops.enable = mkEnableOption "";
  config.flake.modules.nixos.default =
    { config, ... }:
    let
      sshKeyPath = "${config.users.users.${admin.username}.home}/.ssh/id_ed25519";
    in
    {
      imports = [ inputs.sops-nix.nixosModules.sops ];
      config = mkIf cfg.secrets.sops.enable {
        assertions = [
          {
            assertion = hasAttr "users" cfg;
            message = "You must have included the users module and defined users to use `secrets.sops`.";
          }
          {
            assertion = pathExists sopsFilePath;
            message = "You must have created ${sopsFilePath} to set user passwords.";
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
            sopsFile = sopsFilePath;
          };
        }) cfg.users.users;
      };
    };
}
