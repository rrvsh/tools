_: {
  perSystem =
    { pkgs, ... }:
    {
      checks.hermes-active-worker-supervisor =
        pkgs.runCommand "hermes-active-worker-supervisor-check"
          {
            nativeBuildInputs = [
              pkgs.bash
              pkgs.coreutils
              pkgs.gawk
              pkgs.git
              pkgs.jq
              pkgs.python3
            ];
          }
          ''
            mkdir source
            cp ${../modules/hermes-active-worker-supervisor/reconcile.sh} source/reconcile.sh
            cp ${../modules/hermes-active-worker-supervisor/supervisor.py} source/supervisor.py
            cp ${../modules/hermes-active-worker-supervisor/worker_registry.py} source/worker_registry.py
            cp ${../modules/hermes-active-worker-supervisor/test_reconcile.py} source/test_reconcile.py
            cp ${../modules/hermes-active-worker-supervisor/test_supervisor.py} source/test_supervisor.py
            python source/test_reconcile.py
            python source/test_supervisor.py
            touch $out
          '';
    };
}
