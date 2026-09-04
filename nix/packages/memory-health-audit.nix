{ config, ... }:
let
  inherit (config.flake.paths) root;
in
{
  perSystem =
    { pkgs, ... }:
    let
      memoryHealthAudit = pkgs.writeShellApplication {
        name = "memory-health-audit";
        runtimeInputs = [ pkgs.python3 ];
        text = ''
          exec python3 ${root + /scripts/memory_health_audit.py} "$@"
        '';
      };
    in
    {
      packages.memory-health-audit = memoryHealthAudit;
      checks.memory-health-audit =
        pkgs.runCommand "memory-health-audit-tests" { nativeBuildInputs = [ pkgs.python3 ]; }
          ''
            mkdir scripts tests
            cp -R ${root + /scripts}/. scripts/
            cp -R ${root + /tests}/. tests/
            chmod -R u+w scripts tests
            python3 -m unittest discover -s tests -p 'test_memory_health_audit.py'
            touch $out
          '';
    };
}
