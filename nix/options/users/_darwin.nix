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
    users = mapAttrs (username: _userConfig: {
      imports = [ cfg.modules.homeManager.${username} ];
      home = {
        inherit username;
        homeDirectory = config.users.users.${username}.home;
        stateVersion = "25.11";
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
