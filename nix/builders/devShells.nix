{
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          # general
          just

          # nix
          deadnix
          nh
          nixfmt-tree
          statix

          # lua
          luajitPackages.luacheck
          stylua

          # gha yaml
          gh
          zizmor

          # rust
          cargo
          clippy
          rustc
          rustfmt
        ];
      };
    };
}
