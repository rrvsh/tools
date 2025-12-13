{
  cfg,
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (builtins)
    attrNames
    map
    mapAttrs
    ;
  inherit (lib.lists) findFirstIndex;
  knownUsers = attrNames cfg.users.users;
in
{
  imports = map (username: cfg.modules.darwin.${username}) knownUsers ++ [
    inputs.home-manager.darwinModules.home-manager
  ];
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
            push.autoSetupRemote = true;
          };
        };
      };
    }) cfg.users.users;
  };
  security.sudo.extraConfig = "%admin          ALL = (ALL) NOPASSWD: ALL";
  users = { inherit knownUsers; };
  users.users = mapAttrs (username: userConfig: {
    home = "/Users/${username}";
    # first user created is always 501
    uid = 501 + (findFirstIndex (x: x == username) null knownUsers);
    openssh.authorizedKeys.keys = [ userConfig.pubkey ];
  }) cfg.users.users;
}
