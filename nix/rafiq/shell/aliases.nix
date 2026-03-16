{
  config.flake.modules.homeManager.rafiq = {
    programs.fish.interactiveShellInit = ''
      bind \cg 'commandline -r "git add ."; commandline -f execute'
    '';
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
}
