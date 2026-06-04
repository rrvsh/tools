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
      cfg.modules.darwin.profile-graphical
      cfg.modules.darwin.rafiq
      cfg.modules.darwin.neovim
      cfg.modules.darwin.nix-index-comma
      cfg.modules.darwin.pi-agent
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
