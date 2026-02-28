{ inputs, ... }:
{
  config.flake.modules.homeManager.rafiq =
    { pkgs, ... }:
    {
      programs.yazi.plugins = {
        "path-from-root" = pkgs.stdenv.mkDerivation {
          pname = "path-from-root";
          version = "unstable-2024-01-01";
          src = inputs.path-from-root-yazi;
          installPhase = ''
            mkdir -p $out
            cp -r . $out/
          '';
        };
      };
    };
}
