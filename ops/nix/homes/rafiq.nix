{
  flake.modules.darwin.rafiq =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.just ];
    };
  flake.modules.homeManager.rafiq =
    { pkgs, ... }:
    {
      programs.direnv.enable = true;
      programs.direnv.nix-direnv.enable = true;
      home.packages = with pkgs; [
        neovim
        gh
        git
      ];
    };
}
