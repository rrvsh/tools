{
  config.flake = {
    hosts.droid.perseus = { };
    modules.droid.perseus =
      { pkgs, ... }:
      {
        environment.packages = with pkgs; [
          neovim
          git
          openssh
        ];
      };
  };
}
