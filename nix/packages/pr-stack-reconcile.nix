{ config, ... }:
let
  inherit (config.flake.paths) root;
in
{
  perSystem =
    { pkgs, ... }:
    let
      prStackReconcile = pkgs.writeShellApplication {
        name = "pr-stack-reconcile";
        runtimeInputs = [
          pkgs.gh
          pkgs.git
          pkgs.python3
        ];
        text = ''
          exec python3 ${root + /scripts/pr-stack-reconcile.py} "$@"
        '';
      };
    in
    {
      packages.pr-stack-reconcile = prStackReconcile;
      checks.pr-stack-reconcile =
        pkgs.runCommand "pr-stack-reconcile-tests"
          {
            nativeBuildInputs = [
              pkgs.git
              pkgs.python3
            ];
          }
          ''
            export HOME="$TMPDIR/home"
            mkdir -p "$HOME" source/scripts source/tests/pr_stack_reconcile
            cp ${root + /scripts/pr-stack-reconcile.py} source/scripts/pr-stack-reconcile.py
            cp ${
              root + /tests/pr_stack_reconcile/test_pr_stack_reconcile.py
            } source/tests/pr_stack_reconcile/test_pr_stack_reconcile.py
            cd source
            python3 -m unittest discover -s tests/pr_stack_reconcile -v
            touch "$out"
          '';
    };
}
