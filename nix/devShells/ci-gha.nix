{
  perSystem =
    { pkgs, ... }:
    {
      devShells.ci-gha = pkgs.mkShell {
        buildInputs = with pkgs; [
          just
          gh
          zizmor
        ];
      };
    };
}
