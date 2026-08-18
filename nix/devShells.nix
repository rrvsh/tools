{
  perSystem =
    { pkgs, ... }:
    let
      rustShellHook = ''
        export CARGO_HOME="$HOME/.cache/tools/cargo"
        export RUSTUP_HOME="$HOME/.cache/tools/rustup"
        mkdir -p "$CARGO_HOME" "$RUSTUP_HOME"
      '';
      qmlShellHook = pkgs.lib.optionalString pkgs.stdenv.isLinux ''
        export QML_IMPORT_PATH="${pkgs.quickshell}/lib/qt-6/qml:${pkgs.qt6.qtdeclarative}/lib/qt-6/qml''${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
      '';
      common = with pkgs; [ just ];
      nixTools = with pkgs; [
        deadnix
        nixfmt-tree
        statix
      ];
      rustTools = with pkgs; [
        cargo
        clippy
        rustc
        rustfmt
      ];
      luaTools = with pkgs; [
        stylua
        luajitPackages.luacheck
      ];
      ghaTools = with pkgs; [
        gh
        zizmor
      ];
      qmlTools = pkgs.lib.optionals pkgs.stdenv.isLinux (
        with pkgs;
        [
          quickshell
          qt6.qtdeclarative
        ]
      );
    in
    {
      devShells = rec {
        default = ci-all;

        ci-nix = pkgs.mkShell {
          buildInputs = common ++ nixTools;
        };

        ci-rust = pkgs.mkShell {
          buildInputs = common ++ rustTools;
          shellHook = rustShellHook;
        };

        ci-lua = pkgs.mkShell {
          buildInputs = common ++ luaTools;
        };

        ci-gha = pkgs.mkShell {
          buildInputs = common ++ ghaTools;
        };

        ci-qml = pkgs.mkShell {
          buildInputs = common ++ qmlTools;
          shellHook = qmlShellHook;
        };

        ci-all = pkgs.mkShell {
          buildInputs =
            common
            ++ nixTools
            ++ luaTools
            ++ ghaTools
            ++ rustTools
            ++ qmlTools
            ++ (with pkgs; [
              age
              bacon
              nh
              ssh-to-age
            ]);
          shellHook = rustShellHook + qmlShellHook;
        };
      };
    };
}
