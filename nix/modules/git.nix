{
  config.flake = {
    modules.homeManager.rafiq = {
      programs.git = {
        enable = true;
        lfs.enable = true;
        ignores = [
          ".direnv/"
        ];
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
        gparentbranch = "git rev-parse --abbrev-ref origin/HEAD | cut -d'/' -f2-";
        gc = "git commit";
        gcam = "git commit -am";
        quick-commit = "git add . && git commit -m \"$(date +'%Y-%m-%d %H:%M:%S')\" && git push";
        gcamend = "git commit -a --amend --no-edit";
        gcend = "git commit --amend --no-edit";
        gco = "git checkout";
        gcob = "git checkout -b";
        gd = "git diff";
        gdh = "git diff HEAD";
        gdm = "git diff $(gparentbranch)";
        gds = "git diff --staged";
        grc = "git rebase --continue";
        gs = "git status";
        gu = "git push";
        gy = "git pull";
      };
    };
  };
}
