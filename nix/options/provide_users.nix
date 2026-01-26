{ lib, config, ... }:
let
  cfg = config.flake;
  inherit (lib.lists) elemAt;
  inherit (lib.options) mkOption;
  inherit (lib.types)
    str
    attrsOf
    submodule
    bool
    ;
  primaryUsers = lib.attrsets.filterAttrs (_: value: value.primary or false) cfg.users.users;
in
{
  options.flake.users = {
    users = mkOption {
      type = attrsOf (submodule {
        options = {
          primary = mkOption {
            type = bool;
            default = false;
            description = "Denote this user as able to modify the systems controlled by this flake.";
          };
          email = mkOption {
            # NOTE: this is not used for anything now but will be for cloudflare etc
            type = str;
            description = "The email of the user.";
          };
          pubkey = mkOption {
            type = str;
            description = "The SSH public key of the user. Used to add the user as authorised on every machine.";
          };
        };
      });
    };
    admin.username = mkOption {
      internal = true;
      type = str;
    };
  };
  config.flake = {
    users.admin.username = elemAt (builtins.attrNames primaryUsers) 0;
    modules.darwin.default = {
      system.primaryUser = cfg.users.admin.username;
      nix.settings.trusted-users = [ cfg.users.admin.username ];
    };
  };
}
