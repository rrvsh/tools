{ lib, ... }:
let
  inherit (lib.options) mkOption;
  inherit (lib.types) attrsOf raw;
in
{
  options.flake.hosts.droid = mkOption {
    type = attrsOf raw;
    default = { };
    description = "Attribute set where each member is a android host.";
  };
  config.flake.modules.droid.default = {
    # Backup etc files instead of failing to activate generation if a file already exists in /etc
    environment.etcBackupExtension = ".bak";

    # Read the changelog before changing this value
    system.stateVersion = "24.05";

    nix.extraOptions = ''
      experimental-features = nix-command flakes
    '';

    android-integration.termux-setup-storage.enable = true;
  };
}
