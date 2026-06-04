{ config, inputs, ... }:
let
  cfg = config.flake;
in
{
  config.flake.modules.darwin = {
    profile-default = {
      imports = with cfg.modules.darwin; [
        allowedUnfreePackages
        passwordless-sudo
        nix-settings
        ssh-config
        sops-config
        tailscale-config
        darwin-system-defaults
        inputs.mac-app-util.darwinModules.default
      ];
      system = {
        configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
        stateVersion = 6;
      };
      home-manager.sharedModules = [ inputs.mac-app-util.homeManagerModules.default ];
    };
  };
  config.flake.modules.nixos = {
    profile-default = {
      imports = with cfg.modules.nixos; [
        allowedUnfreePackages
        passwordless-sudo
        nix-settings
        ssh-config
        sops-config
        tailscale-config
      ];
      system.stateVersion = "26.05";
      security.polkit.enable = true;
      networking.networkmanager.enable = true;
      programs.dconf.enable = true;
    };
  };
}
