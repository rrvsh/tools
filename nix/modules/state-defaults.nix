{ inputs, ... }:
{
  config.flake.modules.nixos.default = {
    system.stateVersion = "25.11";
  };
  config.flake.modules.darwin.default = {
    nixpkgs.hostPlatform = "aarch64-darwin";
    system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
    system.stateVersion = 6;
  };
}
