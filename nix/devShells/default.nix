{
  perSystem =
    { pkgs, ... }:
    let
      rustShellHook = ''
        export CARGO_HOME="$HOME/.cache/tools/cargo"
        export RUSTUP_HOME="$HOME/.cache/tools/rustup"
        mkdir -p "$CARGO_HOME" "$RUSTUP_HOME"
      '';
    in
    {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          # nix
          just
          deadnix
          nixfmt-tree
          statix
          # lua
          stylua
          luajitPackages.luacheck
          # gha
          gh
          zizmor
          # rust
          cargo
          clippy
          rustc
          rustfmt
          # extras
          age
          awscli2
          bacon
          colima
          docker
          nh
          opentofu
          ssh-to-age
        ];
        shellHook = rustShellHook;
      };
    };
}
