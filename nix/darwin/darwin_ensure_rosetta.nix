{ inputs, ... }:
{
  config.flake = {
    modules.darwin.default = {
      imports = [
        # adds a linux builder that can build x86_64-linux with rosetta
        inputs.nix-rosetta-builder.darwinModules.default
      ];
      nix-rosetta-builder.onDemand = true;
      system.activationScripts.extraActivation.text = ''
        echo >&2 "ensuring rosetta is installed..."
        softwareupdate --install-rosetta --agree-to-license
      '';
    };
  };
}
