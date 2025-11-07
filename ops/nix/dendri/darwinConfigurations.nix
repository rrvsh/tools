{ inputs, config, ... }:
let
  cfg = config.flake;
  inherit (builtins) attrNames;
in
{
  flake.darwinConfigurations.alpha = inputs.nix-darwin.lib.darwinSystem {
    modules = [
      inputs.home-manager.darwinModules.home-manager
      inputs.nix-homebrew.darwinModules.nix-homebrew
      cfg.modules.darwin.leaf
    ];
  };
  flake.modules.darwin.leaf =
    { pkgs, ... }:
    let
      taps = {
        "homebrew/homebrew-core" = inputs.homebrew-core;
        "homebrew/homebrew-cask" = inputs.homebrew-cask;
      };
    in
    {
      environment.systemPackages = [ pkgs.vim ];
      nix.enable = false; # required for nix-darwin and determinate compat
      nix.settings.experimental-features = "nix-command flakes";
      nixpkgs.hostPlatform = "aarch64-darwin";
      homebrew = {
        enable = true;
        taps = attrNames taps;
      };
      nix-homebrew = {
        inherit taps;
        enable = true;
        enableRosetta = true;
        user = cfg.users.admin.username;
        mutableTaps = false;
      };
      system = {
        configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
        stateVersion = 6;
        activationScripts.extraActivation.text = ''
          echo >&2 "ensuring rosetta is installed..."
          softwareupdate --install-rosetta --agree-to-license
        '';
      };
    };
}
