{
  config.flake = {
    modules.darwin.rafiq = {
      homebrew.casks = [ "ghostty" ];
    };
    modules.homeManager.rafiq =
      { pkgs, ... }:
      {
        programs.ghostty = {
          enable = true;
          package = if pkgs.stdenv.isDarwin then null else pkgs.ghostty; # ghostty broken on darwin
        };
      };
  };
}
