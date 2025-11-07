{
  inputs,
  lib,
  config,
  ...
}:
let
  cfg = config.flake;
  inherit (cfg.paths) src;
  inherit (lib.meta) getExe;
in
{
  flake.modules.darwin.rafiq =
    { config, ... }:
    {
      nix.settings.extra-substituters = [ "https://yazi.cachix.org" ];
      nix.settings.extra-trusted-public-keys = [
        "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
      ];
      nixpkgs.overlays = [ inputs.nixpkgs-firefox-darwin.overlay ];
      nixpkgs.config.allowUnfreePredicate =
        pkg:
        builtins.elem (lib.getName pkg) [
          "firefox-bin"
          "slack"
        ];
      homebrew.brews = [ "docker" ];
      homebrew.casks = [ "ghostty" ];
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
      fish = getExe pkgs.fish;
      gdb = "${git} rev-parse --abbrev-ref origin/HEAD | cut -d'/' -f2-";
    in
    {
      imports = [
        inputs.nvf.homeManagerModules.default
        inputs.nix-index-database.homeModules.nix-index
      ];

      home = {
        packages = with pkgs; [
          gh
          firefox-bin
          slack
        ];
        shellAliases = {
          inherit gdb;
          cd = "z";
          v = "$EDITOR";
          e = "${fish} -c 'set -e var; set var ($FINDER); test -n \"$var\"; and $EDITOR $var'";
          t = "$FILE_MANAGER";
          gaa = "${git} add";
          gap = "${git} add -p .";
          gc = "${git} commit";
          gcam = "${git} commit -am";
          gcamend = "${git} commit -a --amend --no-edit";
          gcend = "${git} commit --amend --no-edit";
          gcm = "${git} commit -m";
          gd = "${git} diff";
          gdh = "${git} diff HEAD";
          gdm = "${git} diff $(${gdb})";
          gds = "${git} diff --staged";
          grc = "${git} rebase --continue";
          gs = "${git} status";
          gu = "${git} push";
          gundo = "${git} add . && ${git} stash && ${git} reset HEAD~1 && ${git} stash pop";
          gupdate = "${git} add . && ${git} stash && ${git} checkout $(${gdb}) && ${git} pull && ${git} checkout - && ${git} rebase $(${gdb}) && ${git} stash pop";
          gupdate-main = "${git} add . && ${git} stash && ${git} checkout $(${gdb}) && ${git} pull && ${git} checkout - && ${git} stash pop";
        };
        sessionVariables = {
          FINDER = getExe pkgs.skim;
          FILE_MANAGER = "yy";
        };
      };
      programs = {
        nvf = {
          enable = true;
          defaultEditor = true;
          settings.vim = {
            additionalRuntimePaths = [ src ];
            luaConfigRC.rafiq = "require(\"rafiq\")";
            extraPackages = with pkgs; [ ripgrep ];
            utility.snacks-nvim = {
              enable = true;
            };
          };
        };
        zoxide.enable = true;
        nix-index.enable = true;
        nix-index-database.comma.enable = true;
        mise.enable = true;
        skim = {
          enable = true;
        };
        ripgrep-all.enable = true;
        direnv = {
          enable = true;
          nix-direnv.enable = true;
        };
        firefox = {
          enable = true;
          package = null;
        };
        yazi = {
          enable = true;
          package = inputs.yazi.packages.${pkgs.system}.default;
        };
        ghostty = {
          enable = true;
          package = null;
          clearDefaultKeybinds = true;
        };
      };
    };
}
