{ config, ... }:
let
  inherit (config.flake.accounts.rafiq) username;
in
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
        users.users.${username}.shell = pkgs.fish;
        programs.fish.enable = true;
      };
    darwin.rafiq =
      { pkgs, ... }:
      {
        users.users.${username}.shell = pkgs.fish;
        programs.fish.enable = true;
      };
  };
}
