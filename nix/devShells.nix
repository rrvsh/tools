{
  perSystem =
    { pkgs, ... }:
    let
      rustShellHook = ''
        export CARGO_HOME="$HOME/.cache/tools/cargo"
        export RUSTUP_HOME="$HOME/.cache/tools/rustup"
        mkdir -p "$CARGO_HOME" "$RUSTUP_HOME"
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

        ci-all = pkgs.mkShell {
          buildInputs =
            common
            ++ nixTools
            ++ luaTools
            ++ ghaTools
            ++ rustTools
            ++ (with pkgs; [
              age
              bacon
              nh
              ssh-to-age
            ]);
          shellHook = rustShellHook;
        };
      };
    };
}
