{
  perSystem =
    { pkgs, ... }:
    {
      devShells.ci-nix = pkgs.mkShell {
        buildInputs = with pkgs; [
          just
          deadnix
          nixfmt-tree
          statix
        ];
      };
    };
}
