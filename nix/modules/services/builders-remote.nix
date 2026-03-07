{ config, lib, ... }:
let
  cfg = config.flake;
  inherit (cfg.accounts.rafiq) username;
  nixosRootSshKey = "/root/.ssh/id_ed25519";
  darwinRootSshKey = "/var/root/.ssh/id_ed25519";
  mkActivationScript = from: to: ''
    echo >&2 "copying ssh key to root for remote builders..."
    mkdir -p ${builtins.dirOf to}
    cp ${from} ${to} 2>/dev/null || true
    chmod 600 ${to} 2>/dev/null || true
  '';
  mkBuildMachines = rootKeyPath: [
    {
      hostName = "nemesis";
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      protocol = "ssh";
      maxJobs = 8;
      speedFactor = 2;
      supportedFeatures = [
        "nixos-test"
        "big-parallel"
        "kvm"
      ];
      sshKey = rootKeyPath;
    }
    {
      hostName = "alpha";
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      protocol = "ssh";
      maxJobs = 4;
      speedFactor = 1;
      supportedFeatures = [ "big-parallel" ];
      sshKey = rootKeyPath;
    }
  ];
in
{
  config.flake = {
    modules.nixos.default =
      { config, ... }:
      {
        system.activationScripts.remote-builder-ssh-key.text = lib.optionalString (
          config.users.users ? ${username}
        ) (mkActivationScript "/home/${username}/.ssh/id_ed25519" nixosRootSshKey);
        nix.buildMachines = mkBuildMachines nixosRootSshKey;
      };

    modules.darwin.default = {
      system.activationScripts.extraActivation.text = lib.mkAfter (
        mkActivationScript "/Users/${username}/.ssh/id_ed25519" darwinRootSshKey
      );
      nix.buildMachines = mkBuildMachines darwinRootSshKey;
    };
  };
}
