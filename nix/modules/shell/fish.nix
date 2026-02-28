{
  config.flake.modules = {
    homeManager.rafiq = {
      programs.fish = {
        enable = true;
        interactiveShellInit = ''
          bind \cg 'commandline -r "git add ."; commandline -f execute'
        '';
      };
    };
    nixos.rafiq =
      { pkgs, ... }:
      {
        users.users.rafiq.shell = pkgs.fish;
        programs.fish.enable = true;
      };
    darwin.rafiq =
      { pkgs, ... }:
      {
        users.users.rafiq.shell = pkgs.fish;
        programs.fish.enable = true;
      };
  };
}
