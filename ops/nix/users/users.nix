{ lib, config, ... }:
let
  cfg = config.flake;
  inherit (builtins) mapAttrs attrValues;
  inherit (lib.types) str attrsOf submodule;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf;
  inherit (lib.lists) optional any;
in
{
  options.flake.users.users = mkOption {
    type = attrsOf (submodule {
      options = {
        primary = mkEnableOption "";
        email = mkOption { type = str; };
        pubkey = mkOption { type = str; };
      };
    });
  };
  config.flake.modules.nixos.default =
    { config, ... }:
    {
      assertions = [
        {
          assertion = any (u: u.primary) (attrValues cfg.users.users);
          message = "At least one user must have `primary = true` in flake.users.users.";
        }
      ];
      security.sudo.wheelNeedsPassword = false;
      users = {
        groups.users.gid = 100;
        mutableUsers = false;
        users = mapAttrs (username: userConfig: {
          extraGroups = optional userConfig.primary "wheel";
          hashedPasswordFile = mkIf (cfg.secrets.sops.enable or false
          ) config.sops.secrets."${username}/hashedPassword".path;
          isNormalUser = true;
          openssh.authorizedKeys.keys = [ userConfig.pubkey ];
        }) cfg.users.users;
      };
    };
}
