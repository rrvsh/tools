{ inputs, ... }:
{
  config.flake = {
    nixOnDroidConfigurations.perseus = inputs.nix-on-droid.lib.nixOnDroidConfiguration {
      pkgs = import inputs.nixpkgs-2405 { system = "aarch64-linux"; };
      modules = [
        (
          { pkgs, ... }:
          {
            environment.packages = with pkgs; [
              neovim
              git
              openssh
            ];

            # Backup etc files instead of failing to activate generation if a file already exists in /etc
            environment.etcBackupExtension = ".bak";

            # Read the changelog before changing this value
            system.stateVersion = "24.05";

            nix.extraOptions = ''
              experimental-features = nix-command flakes
            '';

            android-integration.termux-setup-storage.enable = true;
            android-integration.unsupported.enable = true;
          }
        )
      ];
    };
  };
}
