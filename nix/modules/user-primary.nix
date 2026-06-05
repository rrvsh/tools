{ config, lib, ... }:
let
  cfg = config.flake;
  inherit (cfg.paths) root;
  sharedOsConfig =
    {
      config,
      pkgs,
      primaryUser,
      ...
    }:
    {
      nix.settings.trusted-users = [ primaryUser.name ];
      users.users.${primaryUser.name}.shell = pkgs.fish;
      home-manager.users.${primaryUser.name} = {
        home = {
          username = primaryUser.name;
          homeDirectory = config.users.users.${primaryUser.name}.home;
        };
        programs.git.settings = {
          user.name = primaryUser.fullName;
          user.email = primaryUser.email;
          init.defaultBranch = primaryUser.gitDefaultBranch;
        };
      };
    };
in
{
  config.flake.modules.nixos.user-primary =
    { config, primaryUser, ... }:
    {
      imports = [
        sharedOsConfig
        cfg.modules.nixos.user-config
      ];
      programs.fish.enable = true;
      users.users.${primaryUser.name} = {
        description = primaryUser.fullName;
        uid = lib.mkDefault (if primaryUser.uid == null then 1000 else primaryUser.uid);
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        openssh.authorizedKeys.keys = primaryUser.sshAuthorizedKeys;
        hashedPasswordFile = config.sops.secrets."${primaryUser.name}/password".path;
      };
      sops.secrets."${primaryUser.name}/password" = {
        sopsFile = root + "/sops/${primaryUser.name}.yaml";
        neededForUsers = true;
      };
    };
  config.flake.modules.darwin.user-primary =
    { primaryUser, ... }:
    {
      imports = [
        sharedOsConfig
        cfg.modules.darwin.user-config
      ];
      programs.fish.enable = true;
      system.primaryUser = primaryUser.name;
      users.knownUsers = [ primaryUser.name ];
      users.users.${primaryUser.name} = {
        home = "/Users/${primaryUser.name}";
        uid = lib.mkDefault (if primaryUser.uid == null then 501 else primaryUser.uid);
        openssh.authorizedKeys.keys = primaryUser.sshAuthorizedKeys;
      };
    };
}
