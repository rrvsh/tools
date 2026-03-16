{
  config.flake.modules.homeManager.rafiq = {
    programs.git = {
      ignores = [ ".direnv/" ];
      signing = {
        signByDefault = true;
        key = "~/.ssh/id_ed25519.pub";
      };
      settings = {
        user.name = "Mohammad Rafiq";
        user.email = "rafiq@rrv.sh";
        gpg.format = "ssh";
        init.defaultBranch = "prime";
        push.autoSetupRemote = true;
      };
    };
  };
}
