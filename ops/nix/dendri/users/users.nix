{ lib, config, ... }:
let
  cfg = config.flake;
  inherit (builtins)
    attrNames
    map
    mapAttrs
    ;
  inherit (lib.lists) findFirstIndex;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.types)
    attrs
    str
    attrsOf
    submodule
    ;
  knownUsers = attrNames cfg.users.users;
in
{
  options.flake.users.userOptions.apps = mkOption { type = attrs; };
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
        apps = mkOption { type = submodule { options = cfg.users.userOptions.apps; }; };
      };
    });
  };
  config.flake = {
    modules.darwin.leaf =
      { config, ... }:
      {
        imports = map (username: cfg.modules.darwin.${username}) knownUsers;
        security.sudo.extraConfig = "%admin          ALL = (ALL) NOPASSWD: ALL";
        users = { inherit knownUsers; };
        users.users = mapAttrs (username: userConfig: {
          home = "/Users/${username}";
          # first user created is always 501
          uid = 501 + (findFirstIndex (x: x == username) null knownUsers);
          openssh.authorizedKeys.keys = [ userConfig.pubkey ];
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
  };
}
