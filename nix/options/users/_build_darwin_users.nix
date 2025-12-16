{
  cfg,
  inputs,
  lib,
  ...
}:
let
  knownUsers = builtins.attrNames cfg.users.users;
  userModuleList = builtins.map (username: cfg.modules.darwin.${username}) knownUsers;
  getUserIndex = username: lib.lists.findFirstIndex (x: x == username) null knownUsers;
  mapToUsers = fn: builtins.mapAttrs fn cfg.users.users;
in
{
  modules.darwin.default =
    { config, ... }:
    {
      imports = userModuleList ++ [ inputs.home-manager.darwinModules.home-manager ];
      # disable asking for password for sudo
      security.sudo.extraConfig = "%admin          ALL = (ALL) NOPASSWD: ALL";
      users = { inherit knownUsers; };
      users.users = mapToUsers (
        username: userConfig: {
          home = "/Users/${username}";
          # first user created is always 501
          uid = 501 + getUserIndex username;
          openssh.authorizedKeys.keys = [ userConfig.pubkey ];
        }
      );
      home-manager = {
        # keep only one backup of files
        backupFileExtension = "bak";
        overwriteBackup = true;
        useGlobalPkgs = true;
        users = mapToUsers (
          username: _: {
            imports = [ cfg.modules.homeManager.${username} ];
            home = {
              inherit username;
              homeDirectory = config.users.users.${username}.home;
              stateVersion = "25.11";
            };
          }
        );
      };
    };
}
