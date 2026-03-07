{ config, lib, ... }:
let
  cfg = config.flake;
  inherit (cfg.accounts.rafiq) username;
  nixosRootSshKey = "/root/.ssh/id_ed25519";
  darwinRootSshKey = "/var/root/.ssh/id_ed25519";
in
{
  config.flake = {
    modules.nixos.default =
      { config, ... }:
      {
        system.activationScripts.remote-builder-ssh-key.text =
          lib.optionalString (config.users.users ? ${username})
            ''
              echo >&2 "copying ssh key to root for remote builders..."
              mkdir -p ${builtins.dirOf nixosRootSshKey}
              cp /home/${username}/.ssh/id_ed25519 ${nixosRootSshKey} 2>/dev/null || true
              chmod 600 ${nixosRootSshKey} 2>/dev/null || true
            '';
        nix.buildMachines = [
          {
            hostName = "rafiq@nemesis";
            systems = [
              "x86_64-linux"
              "aarch64-linux"
            ];
            protocol = "ssh";
            maxJobs = 8;
            speedFactor = 2;
            supportedFeatures = [
              "nixos-test"
              "big-parallel"
              "kvm"
            ];
            sshKey = nixosRootSshKey;
          }
          {
            hostName = "rafiq@alpha";
            systems = [
              "aarch64-darwin"
              "x86_64-darwin"
            ];
            protocol = "ssh";
            maxJobs = 4;
            speedFactor = 1;
            supportedFeatures = [ "big-parallel" ];
            sshKey = nixosRootSshKey;
          }
        ];
        programs.ssh.knownHosts = {
          nemesis.publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOM5K6SV4mAjtRB/OJOpyirgpHxJrOqaS7ZbbedNLYFV";
          alpha.publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM8wLSVTv2/4n5vgZxWXnGT/mHpCqBCareAg7t6yoE9W";
        };
      };

    modules.darwin.default = {
      system.activationScripts.extraActivation.text = lib.mkAfter ''
        echo >&2 "copying ssh key to root for remote builders..."
        mkdir -p ${builtins.dirOf darwinRootSshKey}
        cp /Users/${username}/.ssh/id_ed25519 ${darwinRootSshKey} 2>/dev/null || true
        chmod 600 ${darwinRootSshKey} 2>/dev/null || true
      '';
      nix.buildMachines = [
        {
            hostName = "rafiq@nemesis";
            systems = [
              "x86_64-linux"
              "aarch64-linux"
            ];
            protocol = "ssh";
            maxJobs = 8;
            speedFactor = 2;
            supportedFeatures = [
              "nixos-test"
              "big-parallel"
              "kvm"
            ];
            sshKey = darwinRootSshKey;
          }
          {
            hostName = "rafiq@alpha";
          systems = [
            "aarch64-darwin"
            "x86_64-darwin"
          ];
          protocol = "ssh";
          maxJobs = 4;
          speedFactor = 1;
          supportedFeatures = [ "big-parallel" ];
            sshKey = darwinRootSshKey;
          }
        ];
      programs.ssh.knownHosts = {
        nemesis.publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOM5K6SV4mAjtRB/OJOpyirgpHxJrOqaS7ZbbedNLYFV";
        alpha.publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM8wLSVTv2/4n5vgZxWXnGT/mHpCqBCareAg7t6yoE9W";
      };
    };
  };
}
