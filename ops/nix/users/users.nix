{ lib, config, ... }:
let
  cfg = config.flake;
  inherit (builtins) mapAttrs;
  inherit (lib.types) str attrsOf submodule;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf;
  inherit (lib.lists) optional;
in
{
  options.flake.manifest.users.users = mkOption {
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
      security.sudo.wheelNeedsPassword = false;
      users = {
        groups.users.gid = 100;
        mutableUsers = false;
        users = mapAttrs (username: userConfig: {
          extraGroups = optional userConfig.primary "wheel";
          hashedPasswordFile = mkIf (cfg.manifest.options.sops.enable or false
          ) config.sops.secrets."${username}/hashedPassword".path;
          isNormalUser = true;
          openssh.authorizedKeys.keys = [ userConfig.pubkey ];
        }) cfg.manifest.users.users;
      };
    };
}
