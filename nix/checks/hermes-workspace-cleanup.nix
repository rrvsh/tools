{ config, lib, ... }:
let
  cfg = config.flake;
in
{
  perSystem =
    { pkgs, system, ... }:
    lib.mkIf (system == "x86_64-linux") (
      let
        cleanup = cfg.packages.${system}.hermes-workspace-cleanup;
      in
      {
        checks.hermes-workspace-cleanup = pkgs.testers.runNixOSTest {
          name = "hermes-workspace-cleanup";
          nodes.machine = {
            environment.systemPackages = [ pkgs.git ];
            systemd.services.cleanup-test = {
              serviceConfig = {
                ExecStart = "${cleanup}/bin/hermes-workspace-cleanup /var/lib/hermes/workspace /run/cleanup-test";
                PrivateTmp = true;
                ProtectSystem = "strict";
                ReadWritePaths = [ "/var/lib/hermes/workspace" ];
                RuntimeDirectory = "cleanup-test";
                Type = "oneshot";
              };
            };
          };
          testScript = ''
            start_all()
            machine.succeed("mkdir -p /var/lib/hermes/workspace")

            machine.succeed("mkdir -p /var/lib/hermes/workspace/stale/.venv")
            machine.succeed("touch /var/lib/hermes/workspace/stale/.venv/pyvenv.cfg")

            machine.succeed("mkdir -p /var/lib/hermes/workspace/active/target")
            machine.succeed("touch /var/lib/hermes/workspace/active/target/.rustc_info.json")

            machine.succeed("git init -q /var/lib/hermes/workspace/tracked")
            machine.succeed("mkdir -p /var/lib/hermes/workspace/tracked/target")
            machine.succeed("touch /var/lib/hermes/workspace/tracked/target/notes")
            machine.succeed("git -C /var/lib/hermes/workspace/tracked add -f target/notes")

            machine.succeed("mkdir -p /var/lib/hermes/workspace/mounted/node_modules")
            machine.succeed("mount -t tmpfs tmpfs /var/lib/hermes/workspace/mounted/node_modules")
            machine.succeed("mkdir /var/lib/hermes/workspace/mounted/node_modules/.bin")

            machine.succeed("find /var/lib/hermes/workspace -exec touch -d '2 hours ago' {} +")
            machine.succeed("mkdir -p /var/lib/hermes/workspace/recent/.cargo-home/registry")
            machine.succeed("systemd-run --unit cleanup-active --property WorkingDirectory=/var/lib/hermes/workspace/active/target ${pkgs.coreutils}/bin/sleep infinity")

            machine.succeed("systemctl start cleanup-test.service")

            machine.succeed("test ! -e /var/lib/hermes/workspace/stale/.venv")
            machine.succeed("test -f /var/lib/hermes/workspace/active/target/.rustc_info.json")
            machine.succeed("test -f /var/lib/hermes/workspace/tracked/target/notes")
            machine.succeed("test -d /var/lib/hermes/workspace/mounted/node_modules/.bin")
            machine.succeed("test -d /var/lib/hermes/workspace/recent/.cargo-home/registry")
            machine.succeed("systemctl is-active cleanup-active.service")
            machine.succeed("journalctl -u cleanup-test.service | grep -F 'Skipping process-referenced build directory'")
            machine.succeed("journalctl -u cleanup-test.service | grep -F 'Skipping unrecognized build directory'")
            machine.succeed("journalctl -u cleanup-test.service | grep -F 'Skipping build directory with a mount'")
            machine.succeed("journalctl -u cleanup-test.service | grep -F 'Skipping recently active build directory'")

            machine.succeed("systemctl stop cleanup-active.service")
            machine.succeed("umount /var/lib/hermes/workspace/mounted/node_modules")
          '';
        };
      }
    );
}
