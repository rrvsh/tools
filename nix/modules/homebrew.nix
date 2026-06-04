{ inputs, ... }:
{
  config.flake.modules.darwin.homebrew =
    { primaryUser, ... }:
    {
      imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

      nix-homebrew = {
        enable = true;
        # Apple Silicon only: also install the Intel Homebrew prefix for Rosetta,
        # allowing `arch -x86_64 brew ...` when an x86_64-only formula/cask is needed.
        enableRosetta = true;
        mutableTaps = false;
        user = primaryUser.name;
        taps = {
          "homebrew/homebrew-core" = inputs.homebrew-core;
          "homebrew/homebrew-cask" = inputs.homebrew-cask;
        };
      };

      homebrew = {
        enable = true;
        taps = builtins.attrNames {
          "homebrew/homebrew-core" = inputs.homebrew-core;
          "homebrew/homebrew-cask" = inputs.homebrew-cask;
        };
      };
    };
}
