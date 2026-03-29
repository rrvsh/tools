{
  inputs,
  config,
  lib,
  ...
}:
let
  cfg = config.flake;
  inherit (inputs.nix-darwin.lib) darwinSystem;
  inherit (builtins) attrNames;
  username = "rafiq";
  nixosHostname = "nemesis";
  darwinRootSshKeyPath = "/var/root/.ssh/id_ed25519";
  remoteBuilderPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM8wLSVTv2/4n5vgZxWXnGT/mHpCqBCareAg7t6yoE9W";
  taps = {
    "homebrew/homebrew-core" = inputs.homebrew-core;
    "homebrew/homebrew-cask" = inputs.homebrew-cask;
  };
  sharedNixSettings = {
    experimental-features = "nix-command flakes";
    eval-cache = true;
    fallback = false;
    use-registries = false;
    flake-registry = "";
    tarball-ttl = 86400;
    connect-timeout = 10;
    http-connections = 50;
    max-substitution-jobs = 32;
    narinfo-cache-negative-ttl = 60;
    max-jobs = "auto";
    cores = 0;
    builders-use-substitutes = true;
    allow-import-from-derivation = false;
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://hyprland.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
  };
in
{
  config.flake.darwinConfigurations.alpha = darwinSystem {
    modules = [
      cfg.modules.darwin.rafiq
      {
        imports = [
          inputs.sops-nix.darwinModules.sops
          inputs.nix-homebrew.darwinModules.nix-homebrew
          inputs.nix-rosetta-builder.darwinModules.default
          inputs.mac-app-util.darwinModules.default
        ];
      }
      {
        networking.hostName = "alpha";

        # nix
        nixpkgs = {
          hostPlatform = "aarch64-darwin";
          config.allowUnfreePredicate = pkg: builtins.elem (lib.strings.getName pkg) [ "firefox-bin" ];
          overlays = [ inputs.nixpkgs-firefox-darwin.overlay ];
        };
        system = {
          configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
          stateVersion = 6;
        };
        nix = {
          distributedBuilds = true;
          buildMachines = [
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
          settings = sharedNixSettings // {
            extra-substituters = sharedNixSettings.extra-substituters ++ [ "https://yazi.cachix.org" ];
            extra-trusted-public-keys = sharedNixSettings.extra-trusted-public-keys ++ [
              "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
            ];
          };
        };

        # remote builder ssh key
        programs.ssh.knownHosts.${nixosHostname}.publicKey = remoteBuilderPubkey;

        # security
        security.sudo.extraConfig = "%admin          ALL = (ALL) NOPASSWD: ALL";
        services.openssh = {
          enable = true;
          extraConfig = ''
            KbdInteractiveAuthentication no
            PasswordAuthentication no
            PermitRootLogin no
          '';
        };

        # tailscale
        services.tailscale.enable = true;

        # rosetta
        nix-rosetta-builder.onDemand = true;

        # homebrew
        homebrew = {
          enable = true;
          taps = attrNames taps;
          brews = [ "docker" ];
        };
        nix-homebrew = {
          inherit taps;
          enable = true;
          enableRosetta = true;
          mutableTaps = false;
          user = username;
        };

        # mac-app-util
        home-manager.sharedModules = [ inputs.mac-app-util.homeManagerModules.default ];

        # system
        system = {
          primaryUser = username;
          activationScripts.extraActivation.text = lib.mkMerge [
            (lib.mkBefore ''
              echo >&2 "ensuring rosetta is installed..."
              softwareupdate --install-rosetta --agree-to-license
            '')
            ''
              echo >&2 "copying ssh key to root..."
              mkdir -p ${builtins.dirOf darwinRootSshKeyPath}
              cp /Users/${username}/.ssh/id_ed25519 \
                ${darwinRootSshKeyPath} 2>/dev/null \
                || true
              chmod 600 ${darwinRootSshKeyPath} 2>/dev/null || true
              echo >&2 "disabling sleep..."
              sudo pmset -a disablesleep 1
              echo >&2 "disabling display sleep..."
              sudo pmset -a displaysleep 0
            ''
          ];
          defaults.NSGlobalDomain = {
            "com.apple.swipescrolldirection" = false;
          };
          keyboard = {
            enableKeyMapping = true;
            remapCapsLockToEscape = true;
          };
        };
      }
    ];
  };
}
