{ inputs, config, ... }:
let
  cfg = config.flake;
in
{
  config.flake = {
    modules.darwin.rafiq = {
      nix.settings.extra-substituters = [ "https://yazi.cachix.org" ];
      nix.settings.extra-trusted-public-keys = [
        "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
      ];
    };
    modules.homeManager.rafiq =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      let
        path-from-root = pkgs.stdenv.mkDerivation {
          pname = "path-from-root";
          version = "unstable-2024-01-01";
          src = inputs.path-from-root-yazi;
          installPhase = ''
            mkdir -p $out
            cp -r . $out/
          '';
        };

        git-commit-browser = pkgs.stdenvNoCC.mkDerivation {
          pname = "git-commit-browser.yazi";
          version = "0.1.0";
          src = cfg.paths.root + /yazi/plugins/git-commit-browser.yazi;
          installPhase = ''
            mkdir -p $out/share/yazi/plugins
            cp -r . $out/share/yazi/plugins/git-commit-browser.yazi
          '';
        };

        test-yazi-plugin = pkgs.writeShellScriptBin "test-yazi-plugin" (
          lib.fileContents (cfg.paths.root + "/scripts/test-yazi-plugin.sh")
        );
      in
      {
        home.shellAliases.t = config.programs.yazi.shellWrapperName;

        home.activation.test-yazi-plugin = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          ${test-yazi-plugin}/bin/test-yazi-plugin || true
        '';

        programs.yazi = {
          enable = true;
          # this will use the binary cache configured above
          # but only after it is registered i.e. after a system rebuild is done with the above and **without this**
          # so comment this package out the first time you rebuild, then uncomment it and rebuild again
          package = inputs.yazi.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
            runtimeDeps = ps: ps ++ [ pkgs.exiftool ];
          };
          plugins = {
            "path-from-root" = path-from-root;
            "git-commit-browser" = "${git-commit-browser}/share/yazi/plugins/git-commit-browser.yazi";
          };
          keymap = {
            mgr.prepend_keymap = [
              {
                on = [
                  "c"
                  "r"
                ];
                run = "plugin path-from-root";
                desc = "Copies path from git root";
              }
              {
                on = "]";
                run = "plugin git-commit-browser -- next";
                desc = "Next commit (older)";
              }
              {
                on = "[";
                run = "plugin git-commit-browser -- prev";
                desc = "Previous commit (newer)";
              }
              {
                on = [ "g" "[" ];
                run = "plugin git-commit-browser -- head";
                desc = "Return to HEAD/original";
              }
              {
                on = [ "g" "]" ];
                run = "plugin git-commit-browser -- select";
                desc = "Select commit interactively";
              }
            ];
          };
        };
      };
  };
}
