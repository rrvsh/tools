{
  config.flake.modules.darwin.rafiq = {
    system.activationScripts.extraActivation.text = ''
      echo >&2 "ensuring rosetta is installed..."
      softwareupdate --install-rosetta --agree-to-license
    '';
  };
}
