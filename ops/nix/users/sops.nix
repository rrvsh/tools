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
  inherit (lib.attrsets) mapAttrs';
  inherit (cfg.manifest.users) admin;
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in
{
  options.flake.manifest.users.sops.enable = mkEnableOption "";
  config.flake.modules.nixos.default =
    { config, ... }:
    let
      sshKeyPath = "${config.users.users.${admin.username}.home}/.ssh/id_ed25519";
    in
    {
      imports = [ inputs.sops-nix.nixosModules.sops ];
      config = mkIf cfg.manifest.users.sops.enable {
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
            sopsFile = secrets + /users.yaml;
          };
        }) cfg.manifest.users;
      };
    };
}
