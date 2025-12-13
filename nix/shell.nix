{
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          # general
          bacon
          caligula
          just
          sops
          ssh-to-age
          zstd

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
        ];
      };
    };
}
