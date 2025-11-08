{
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          # general
          just
          sops

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
