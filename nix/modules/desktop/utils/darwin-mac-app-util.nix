# Disable home-manager's copyApps on Darwin.
# We use mac-app-util instead, which creates trampoline apps that work with
# Spotlight without requiring App Management permissions. This avoids the
# permission reset issues that occur with copyApps' tccutil reset behavior.
{ inputs, lib, ... }:
{
  config.flake = {
    modules.homeManager.rafiq =
      { pkgs, ... }:
      lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        # Disable copyApps entirely - mac-app-util handles app launching instead
        targets.darwin.copyApps.enable = lib.mkForce false;
      };
    modules.darwin.default = {
      imports = [ inputs.mac-app-util.darwinModules.default ];
      home-manager.sharedModules = [ inputs.mac-app-util.homeManagerModules.default ];
    };
  };
}
