{
  config.flake.modules.darwin.darwin-system-defaults = _: {
    system = {
      activationScripts.extraActivation.text = ''
        echo >&2 "disabling sleep..."
        sudo pmset -a disablesleep 1
        echo >&2 "disabling display sleep..."
        sudo pmset -a displaysleep 0
      '';
      defaults.NSGlobalDomain."com.apple.swipescrolldirection" = false;
      keyboard = {
        enableKeyMapping = true;
        remapCapsLockToEscape = true;
      };
    };
  };
}
