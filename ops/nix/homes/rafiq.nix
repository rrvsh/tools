{ inputs, lib, ... }:
let
  inherit (lib.meta) getExe;
in
{
  flake.modules.darwin.rafiq =
    { config, ... }:
    {
      nixpkgs.overlays = [ inputs.nixpkgs-firefox-darwin.overlay ];
      nixpkgs.config.allowUnfreePredicate =
        pkg:
        builtins.elem (lib.getName pkg) [
          "firefox-bin"
        ];
      system = {
        activationScripts = {
          extraActivation.text = lib.mkAfter config.system.activationScripts.pmset.text;
          pmset.text = ''
            echo >&2 "configuring power management..."
            sudo pmset -a disablesleep 1
          '';
        };
        defaults.NSGlobalDomain."com.apple.swipescrolldirection" = false;
        keyboard.enableKeyMapping = true;
        keyboard.remapCapsLockToEscape = true;
      };
    };
  flake.modules.homeManager.rafiq =
    { pkgs, ... }:
    let
      git = getExe pkgs.git;
      gdb = "${git} rev-parse --abbrev-ref origin/HEAD | cut -d'/' -f2-";
    in
    {
      home = {
        packages = with pkgs; [
          gh
          firefox-bin
        ];
        shellAliases = {
          inherit gdb;
          v = "$EDITOR";
          gs = "${git} status";
          gc = "${git} commit";
          gcend = "${git} commit --amend --no-edit";
          gcamend = "${git} commit -a --amend --no-edit";
          gcm = "${git} commit -m";
          gcam = "${git} commit -am";
          gu = "${git} push";
          gd = "${git} diff";
          gdh = "${git} diff HEAD";
          gds = "${git} diff --staged";
          gdm = "${git} diff $(${gdb})";
          gundo = "${git} add . && ${git} stash && ${git} reset HEAD~1 && ${git} stash pop";
          gupdate = "${git} add . && ${git} stash && ${git} checkout $(${gdb}) && ${git} pull && ${git} checkout - && ${git} rebase $(${gdb}) && ${git} stash pop";
          gupdate-main = "${git} add . && ${git} stash && ${git} checkout $(${gdb}) && ${git} pull && ${git} checkout - && ${git} stash pop";
        };
        sessionVariables = {
          EDITOR = getExe pkgs.neovim;
        };
      };
      programs = {
        direnv = {
          enable = true;
          nix-direnv.enable = true;
        };
        firefox = {
          enable = true;
          package = null;
        };
        mise.enable = true;
      };
    };
}
