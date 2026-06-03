{ inputs, ... }:
{
  config.flake.modules.darwin.rosetta-builder =
    { lib, ... }:
    {
      imports = [ inputs.nix-rosetta-builder.darwinModules.default ];
      nix-rosetta-builder.onDemand = true;
      system.activationScripts.extraActivation.text = lib.mkBefore ''
        echo >&2 "ensuring rosetta is installed..."
        softwareupdate --install-rosetta --agree-to-license
      '';
    };
}
