{ inputs, ... }:
{
  config.flake.modules.darwin.default = {
    imports = [
      inputs.nix-rosetta-builder.darwinModules.default
    ];
    nix-rosetta-builder.onDemand = true;
    system.activationScripts.extraActivation.text = ''
      echo >&2 "ensuring rosetta is installed..."
      softwareupdate --install-rosetta --agree-to-license
    '';
  };
}
