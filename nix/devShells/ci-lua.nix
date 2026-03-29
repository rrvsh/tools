{
  perSystem =
    { pkgs, ... }:
    {
      devShells.ci-lua = pkgs.mkShell {
        buildInputs = with pkgs; [
          just
          stylua
          luajitPackages.luacheck
        ];
      };
    };
}
