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
      devShells.ci-rs = pkgs.mkShell {
        buildInputs = with pkgs; [
          just
          cargo
          clippy
          rustc
          rustfmt
        ];
        shellHook = rustShellHook;
      };
    };
}
