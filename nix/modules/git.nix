{
  config.flake = {
    modules.homeManager.rafiq = {
      programs.git = {
        enable = true;
        signing = {
          signByDefault = true;
          # this needs to be a tilde because git cant use $HOME
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
      home.shellAliases = {
        gc = "git commit";
        gcam = "git commit -am";
        gcamend = "git commit -a --amend --no-edit";
        gcend = "git commit --amend --no-edit";
        gd = "git diff";
        gdh = "git diff HEAD";
        gdm = "git diff $(gparentbranch)";
        grc = "git rebase --continue";
        gs = "git status";
        gu = "git push";
        gupdate = "git add . && git stash && git checkout $(gparentbranch) && git pull && git checkout - && git rebase $(gparentbranch) && git stash pop";
        gparentbranch = "git rev-parse --abbrev-ref origin/HEAD | cut -d'/' -f2-";
      };
    };
  };
}
