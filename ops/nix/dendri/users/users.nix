{ lib, config, ... }:
let
  cfg = config.flake;
  inherit (builtins)
    attrNames
    attrValues
    hasAttr
    listToAttrs
    map
    mapAttrs
    ;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.lists) findFirstIndex optional any;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.types) str attrsOf submodule;
  knownUsers = attrNames cfg.users.users;
  userShells = mapAttrsToList (_: value: value.shell) cfg.users.users;
in
{
  options.flake.users.users = mkOption {
    type = attrsOf (submodule {
      options = {
        primary = mkEnableOption "";
        fullName = mkOption { type = str; };
        email = mkOption { type = str; };
        pubkey = mkOption { type = str; };
        shell = mkOption {
          type = str;
          default = "fish";
        };
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
    { config, pkgs, ... }:
    {
      assertions = [
        {
          assertion = any (pkg_name: hasAttr pkg_name config.programs) userShells;
          message = "users.users.<name>.shell must be set to a valid shell name.";
        }
      ];
      imports = map (username: cfg.modules.darwin.${username}) knownUsers;
      security.sudo.extraConfig = "%admin          ALL = (ALL) NOPASSWD: ALL";
      users = { inherit knownUsers; };
      users.users = mapAttrs (username: userConfig: {
        home = "/Users/${username}";
        # first user created is always 501
        uid = 501 + (findFirstIndex (x: x == username) null knownUsers);
        openssh.authorizedKeys.keys = [ userConfig.pubkey ];
        shell = pkgs.${userConfig.shell};
      }) cfg.users.users;
      programs = listToAttrs (
        map (x: {
          name = x;
          value.enable = true;
        }) userShells
      );
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
            ${userConfig.shell}.enable = true;
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
