{
  inputs,
  config,
  ...
}:
let
  cfg = config.flake;
  inherit (inputs.nixpkgs.lib) nixosSystem;
  username = "rafiq";
  darwinHostname = "alpha";
  linuxRootSshKeyPath = "/root/.ssh/id_ed25519";
  remoteBuilderPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM8wLSVTv2/4n5vgZxWXnGT/mHpCqBCareAg7t6yoE9W";
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
  config.flake.nixosConfigurations.nemesis = nixosSystem {
    modules = [
      cfg.modules.nixos.rafiq
      (
        {
          config,
          pkgs,
          lib,
          modulesPath,
          ...
        }:
        {
          imports = [
            inputs.sops-nix.nixosModules.sops
            inputs.hyprland.nixosModules.default
            (modulesPath + "/installer/scan/not-detected.nix")
          ];

          networking.hostName = "nemesis";
          time.timeZone = "Asia/Singapore";

          # nix
          nixpkgs = {
            hostPlatform = lib.mkDefault "x86_64-linux";
            config.allowUnfreePredicate =
              pkg:
              builtins.elem (lib.strings.getName pkg) [
                "nvidia-persistenced"
                "nvidia-settings"
                "nvidia-x11"
                "steam"
                "steam-original"
                "steam-run"
                "steam-unwrapped"
              ];
          };
          nix = {
            distributedBuilds = true;
            buildMachines = [
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
            settings = sharedNixSettings;
          };
          system.stateVersion = "25.11";

          # remote builder ssh key
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
          # security
          security = {
            sudo.wheelNeedsPassword = false;
            polkit.enable = true;
            rtkit.enable = true;
          };

          # services
          services = {
            openssh = {
              enable = true;
              settings = {
                KbdInteractiveAuthentication = false;
                PasswordAuthentication = false;
                PermitRootLogin = "no";
              };
            };

            # tailscale
            tailscale = {
              enable = true;
              authKeyFile = config.sops.secrets."tailscale/authkey".path;
            };

            # nvidia
            xserver.videoDrivers = [ "nvidia" ];

            # pipewire
            pipewire = {
              enable = true;
              alsa.enable = true;
              alsa.support32Bit = true;
              pulse.enable = true;
              jack.enable = true;
              wireplumber.enable = true;
            };
          };
          sops.secrets."tailscale/authkey" = {
            sopsFile = cfg.paths.root + "/sops/tailscale.yaml";
          };

          # hardware
          boot = {
            initrd.availableKernelModules = [
              "nvme"
              "xhci_pci"
              "ahci"
              "usbhid"
              "usb_storage"
              "sd_mod"
            ];
            initrd.kernelModules = [ ];
            kernelModules = [ "kvm-amd" ];
            extraModulePackages = [ ];
            loader.systemd-boot = {
              enable = true;
              edk2-uefi-shell.enable = true;
              windows."11-pro" = {
                title = "Windows 11 Pro";
                efiDeviceHandle = "HD0d";
              };
            };
            loader.efi.canTouchEfiVariables = true;
            kernelPackages = pkgs.linuxPackages_latest;
          };

          fileSystems."/" = {
            device = "/dev/disk/by-uuid/13ad8c18-69ff-4288-8dec-bc50f0f5374c";
            fsType = "ext4";
          };
          fileSystems."/boot" = {
            device = "/dev/disk/by-uuid/BC86-01BB";
            fsType = "vfat";
            options = [
              "fmask=0077"
              "dmask=0077"
            ];
          };
          swapDevices = [ ];
          hardware = {
            cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
            graphics = {
              enable = true;
              enable32Bit = true;
            };
            nvidia = {
              modesetting.enable = true;
              nvidiaSettings = true;
              package = config.boot.kernelPackages.nvidiaPackages.stable;
              open = false;
            };
            i2c.enable = true;
          };
          networking.networkmanager.enable = true;
          environment.sessionVariables = {
            GBM_BACKEND = "nvidia-drm";
            __GLX_VENDOR_LIBRARY_NAME = "nvidia";
            LIBVA_DRIVER_NAME = "nvidia";
            NIXOS_OZONE_WL = "1";
          };

          # hyprland + steam + desktop programs
          programs = {
            ssh.knownHosts.${darwinHostname}.publicKey = remoteBuilderPubkey;
            hyprland = {
              enable = true;
              xwayland.enable = true;
              package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
              portalPackage =
                inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
            };
            dconf.enable = true;
            steam = {
              enable = true;
              remotePlay.openFirewall = true;
              dedicatedServer.openFirewall = true;
              localNetworkGameTransfers.openFirewall = true;
            };
            gamemode.enable = true;
            gamescope.enable = true;
          };
          assertions = [
            {
              assertion = config.networking.hostName != "";
              message = "Hyprland module expects a hostName.";
            }
          ];
          xdg.portal.enable = true;
          xdg.portal.extraPortals = [ config.programs.hyprland.portalPackage ];
        }
      )
    ];
  };
}
