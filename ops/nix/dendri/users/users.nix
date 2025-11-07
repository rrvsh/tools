{ lib, config, ... }:
let
  cfg = config.flake;
  inherit (builtins) mapAttrs attrNames attrValues;
  inherit (lib.types) str attrsOf submodule;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf;
  inherit (lib.lists) findFirstIndex optional any;
  knownUsers = attrNames cfg.users.users;
in
{
  options.flake.users.users = mkOption {
    type = attrsOf (submodule {
      options = {
        primary = mkEnableOption "";
        fullName = mkOption { type = str; };
        email = mkOption { type = str; };
        pubkey = mkOption { type = str; };
        defaultBranchName = mkOption {
          type = str;
          default = "main";
        };
      };
    });
  };
  config.flake.modules.nixos.leaf =
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
          hashedPasswordFile = mkIf (
            cfg.users.secrets.type == "sops"
          ) config.sops.secrets."${username}/hashedPassword".path;
          isNormalUser = true;
          openssh.authorizedKeys.keys = [ userConfig.pubkey ];
        }) cfg.users.users;
      };
    };
  config.flake.modules.darwin.leaf =
    { config, ... }:
    {
      imports = map (username: cfg.modules.darwin.${username}) knownUsers;
      security.sudo.extraConfig = "%admin          ALL = (ALL) NOPASSWD: ALL";
      users = {
        inherit knownUsers;
      };
      users.users = mapAttrs (username: _: {
        home = "/Users/${username}";
        # first user created is always 501
        uid = 501 + (findFirstIndex (x: x == username) null knownUsers);
      }) cfg.users.users;
      home-manager = {
        useGlobalPkgs = true;
        users = mapAttrs (username: userConfig: {
          imports = [ cfg.modules.homeManager.${username} ];
          home = {
            inherit username;
            homeDirectory = config.users.users.${username}.home;
            stateVersion = "25.11";
          };
          programs = {
            git = {
              enable = true;
              signing = {
                signByDefault = true;
                key = "~/.ssh/id_ed25519.pub";
              };
              settings = {
                user.name = userConfig.fullName;
                user.email = userConfig.email;
                gpg.format = "ssh";
                init.defaultBranch = userConfig.defaultBranchName;
              };
            };
          };
        }) cfg.users.users;
      };
    };
}
