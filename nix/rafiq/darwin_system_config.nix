{
  config.flake.modules.darwin.rafiq = {
    system = {
      activationScripts.extraActivation.text = ''
        echo >&2 "configuring power management..."
        sudo pmset -a disablesleep 1
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
