{
  inputs,
  config,
  ...
}:
let
  cfg = config.flake;
in
{
  config.flake.darwinConfigurations.alpha = inputs.nix-darwin.lib.darwinSystem {
    modules = [
      cfg.modules.darwin.profile-default
      cfg.modules.darwin.profile-desktop
      cfg.modules.darwin.rafiq
      cfg.modules.darwin.neovim
      cfg.modules.darwin.homebrew
      cfg.modules.darwin.yazi
      cfg.modules.darwin.rosetta-builder
      {
        networking.hostName = "alpha";
        system.primaryUser = "rafiq";
        nixpkgs.hostPlatform = "aarch64-darwin";
      }
    ];
  };
}
