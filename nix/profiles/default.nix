{ config, inputs, ... }:
let
  cfg = config.flake;
in
{
  config.flake.modules.darwin.profile-default = {
    imports = with cfg.modules.darwin; [
      allowedUnfreePackages
      auto-upgrade
      homebrew
      nix-settings
      ssh-config
    ];
    system = {
      configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
      stateVersion = 6;
    };
  };
  config.flake.modules.nixos.profile-default = {
    imports = with cfg.modules.nixos; [
      allowedUnfreePackages
      auto-upgrade
      nix-settings
      ssh-config
    ];
    system.stateVersion = "26.05";
  };
}
