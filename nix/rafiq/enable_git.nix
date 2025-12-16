{
  config.flake.modules.homeManager.rafiq = {
    programs.git = {
      enable = true;
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
    home.shellAliases = {
      gap = "git add -p .";
      gc = "git commit";
      gcam = "git commit -am";
      gcamend = "git commit -a --amend --no-edit";
      gcend = "git commit --amend --no-edit";
      gd = "git diff";
      gdh = "git diff HEAD";
      gdm = "git diff $(gparentbranch)";
      gds = "git diff --staged";
      grc = "git rebase --continue";
      gs = "git status";
      gu = "git push";
      gupdate = "git add . && git stash && git checkout $(gdb) && git pull && git checkout - && git rebase $(gdb) && git stash pop";
      gparentbranch = "git rev-parse --abbrev-ref origin/HEAD | cut -d'/' -f2-";
    };
  };
}
