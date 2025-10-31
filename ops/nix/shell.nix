{
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          deadnix
          gh
          git
          just
          nh
          nixfmt-tree
          sops
          statix
          zizmor
        ];
      };
    };
}
