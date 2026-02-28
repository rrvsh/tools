{ config, ... }:
let
  account = config.flake.accounts.rafiq;
in
{
  config.flake.modules.homeManager.rafiq = {
    programs.git = {
      enable = true;
      lfs.enable = true;
      ignores = [
        ".direnv/"
      ];
      signing = {
        signByDefault = true;
        key = "~/.ssh/id_ed25519.pub";
      };
      settings = {
        user.name = account.fullName;
        user.email = account.email;
        gpg.format = "ssh";
        init.defaultBranch = "prime";
        push.autoSetupRemote = true;
      };
    };
  };
}
