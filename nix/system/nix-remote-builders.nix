{ lib, ... }:
let
  username = "rafiq";
  pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM8wLSVTv2/4n5vgZxWXnGT/mHpCqBCareAg7t6yoE9W";
  nixosHostname = "nemesis";
  darwinHostname = "alpha";
  linuxRootSshKeyPath = "/root/.ssh/id_ed25519";
  darwinRootSshKeyPath = "/var/root/.ssh/id_ed25519";
in
{
  config.flake = {
    modules.nixos.remote-darwin-builder =
      { config, ... }:
      {
        system.activationScripts.remote-builder-ssh-key.text =
          lib.optionalString (config.users.users ? ${username})
            ''
              echo >&2 "copying ssh key to root..."
              mkdir -p ${builtins.dirOf linuxRootSshKeyPath}
              cp /home/${username}/.ssh/id_ed25519 \
                ${linuxRootSshKeyPath} 2>/dev/null \
                || true
              chmod 600 ${linuxRootSshKeyPath} 2>/dev/null \
                || true
            '';
        nix.buildMachines = [
          {
            hostName = "${username}@${darwinHostname}";
            systems = [
              "aarch64-darwin"
              "x86_64-darwin"
            ];
            protocol = "ssh";
            maxJobs = 8;
            speedFactor = 2;
            supportedFeatures = [ "big-parallel" ];
            sshKey = linuxRootSshKeyPath;
          }
        ];
        programs.ssh.knownHosts = {
          ${darwinHostname}.publicKey = pubkey;
        };
      };
    modules.darwin.remote-builder-darwin = {
      system.activationScripts.extraActivation.text = lib.mkAfter ''
        echo >&2 "copying ssh key to root..."
        mkdir -p ${builtins.dirOf darwinRootSshKeyPath}
        cp /Users/${username}/.ssh/id_ed25519 \
          ${darwinRootSshKeyPath} 2>/dev/null \
          || true
        chmod 600 ${darwinRootSshKeyPath} 2>/dev/null || true
      '';
      nix.buildMachines = [
        {
          hostName = "${username}@${nixosHostname}";
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
          sshKey = darwinRootSshKeyPath;
        }
      ];
      programs.ssh.knownHosts = {
        ${nixosHostname}.publicKey = pubkey;
      };
    };
  };
}
