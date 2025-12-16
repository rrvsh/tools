{ lib, ... }:
{
  config.flake.modules.homeManager.rafiq =
    { pkgs, ... }:
    {
      programs.skim = {
        enable = true;
        defaultCommand = "${lib.getExe pkgs.ripgrep} --files --hidden --glob '!.git'";
      };
    };
}
