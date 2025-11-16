{
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          # general
          just
          sops
          ssh-to-age
          zstd
          caligula
          bacon

          # nix
          nixfmt-tree
          deadnix
          statix
          nh

          # lua
          luajitPackages.luacheck
          stylua

          # gha yaml
          zizmor
        ];
      };
    };
}
