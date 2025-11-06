{ inputs, config, ... }:
let
  cfg = config.flake;
in
{
  flake.darwinConfigurations.alpha = inputs.nix-darwin.lib.darwinSystem {
    modules = [ cfg.modules.darwin.leaf ];
  };
  flake.modules.darwin.leaf =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.vim ];
      nix.enable = false; # required for nix-darwin and determinate compat
      nix.settings.experimental-features = "nix-command flakes";
      system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
      system.stateVersion = 6;
      nixpkgs.hostPlatform = "aarch64-darwin";
    };
}
