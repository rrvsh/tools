{
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          gh
          nh
          just
          sops
          statix
          deadnix
          nixfmt-tree
        ];
      };
    };
}
