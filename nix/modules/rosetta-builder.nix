{ inputs, ... }:
{
  config.flake.modules.darwin.rosetta-builder =
    { lib, ... }:
    {
      imports = [
        # An existing Linux builder is needed to initially bootstrap `nix-rosetta-builder`.
        # If one isn't already available: comment out the `nix-rosetta-builder` module below,
        # uncomment this `linux-builder` module, and run `darwin-rebuild switch`:
        # { nix.linux-builder.enable = true; }
        # Then: uncomment `nix-rosetta-builder`, remove `linux-builder`, and `darwin-rebuild switch`
        # a second time. Subsequently, `nix-rosetta-builder` can rebuild itself.
        inputs.nix-rosetta-builder.darwinModules.default
      ];
      nix-rosetta-builder.onDemand = true;
      system.activationScripts.extraActivation.text = lib.mkBefore ''
        echo >&2 "ensuring rosetta is installed..."
        softwareupdate --install-rosetta --agree-to-license
      '';
    };
}
