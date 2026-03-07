{ config, lib, ... }:
let
  cfg = config.flake;
  inherit (cfg.accounts.rafiq) username;
  mkActivationScript = from: to: ''
    echo >&2 "copying ssh key to root for remote builders..."
    mkdir -p ${builtins.dirOf to}
    cp ${from} ${to} 2>/dev/null || true
    chmod 600 ${to} 2>/dev/null || true
  '';
  mkBuildMachine =
    {
      hostName,
      kernel,
      maxJobs ? 4,
      speedFactor ? 1,
    }:
    {
      inherit hostName maxJobs speedFactor;
      systems = [
        "aarch64-${kernel}"
        "x86_64-${kernel}"
      ];
      protocol = "ssh";
      supportedFeatures = [
        "big-parallel"
      ]
      ++ lib.optionals (kernel == "linux") [
        "nixos-test"
        "kvm"
      ];
    };
  mkBuildMachines = rootKeyPath: [
    ((mkBuildMachine "nemesis" "linux" 8 2) // { sshKey = rootKeyPath; })
    ((mkBuildMachine "alpha" "darwin") // { sshKey = rootKeyPath; })
  ];
in
{
  config.flake = {
    modules.nixos.default =
      { config, ... }:
      {
        system.activationScripts.remote-builder-ssh-key.text = lib.optionalString (
          config.users.users ? ${username}
        ) (mkActivationScript "/home/${username}/.ssh/id_ed25519" "/root/.ssh/id_ed25519");
        nix.buildMachines = mkBuildMachines "/root/.ssh/id_ed25519";
      };

    modules.darwin.default = {
      system.activationScripts.extraActivation.text = lib.mkAfter (
        mkActivationScript "/Users/${username}/.ssh/id_ed25519" "/var/root/.ssh/id_ed25519"
      );
      nix.buildMachines = mkBuildMachines "/var/root/.ssh/id_ed25519";
    };
  };
}
