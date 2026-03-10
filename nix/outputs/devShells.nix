{
  perSystem =
    { pkgs, ... }:
    let
      ciBaseInputs = with pkgs; [
        just
      ];
      rustShellHook = ''
        export CARGO_HOME="$HOME/.cache/tools/cargo"
        export RUSTUP_HOME="$HOME/.cache/tools/rustup"
        mkdir -p "$CARGO_HOME" "$RUSTUP_HOME"
      '';
      ciInputs = {
        gha =
          ciBaseInputs
          ++ (with pkgs; [
            gh
            zizmor
          ]);
        lua =
          ciBaseInputs
          ++ (with pkgs; [
            stylua
            luajitPackages.luacheck
          ]);
        nix =
          ciBaseInputs
          ++ (with pkgs; [
            deadnix
            nixfmt-tree
            statix
          ]);
        rs =
          ciBaseInputs
          ++ (with pkgs; [
            cargo
            clippy
            rustc
            rustfmt
          ]);
      };
      defaultInputs =
        ciInputs.nix
        ++ ciInputs.lua
        ++ ciInputs.gha
        ++ ciInputs.rs
        ++ (with pkgs; [
          age
          awscli2
          bacon
          colima
          docker
          nh
          opentofu
          ssh-to-age
        ]);
      mkShell = inputs: pkgs.mkShell { buildInputs = inputs; };
      mkRustShell =
        inputs:
        pkgs.mkShell {
          buildInputs = inputs;
          shellHook = rustShellHook;
        };
    in
    {
      devShells = {
        default = mkRustShell defaultInputs;
        ci-gha = mkShell ciInputs.gha;
        ci-lua = mkShell ciInputs.lua;
        ci-nix = mkShell ciInputs.nix;
        ci-rs = mkRustShell ciInputs.rs;
      };
    };
}
