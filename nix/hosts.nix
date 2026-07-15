{ config, inputs, ... }:
let
  cfg = config.flake;
  rrvshSshAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdsZyY3gu8IGB8MzMnLdh+ClDxQQ2RYG9rkeetIKq8n"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDAgeb4QgH9YPUfS9lG2GMC1/fnxaxCX2F+lbgfxN1d6"
  ];
  rafiq = {
    name = "rafiq";
    fullName = "Mohammad Rafiq";
    email = "rafiq@rrv.sh";
    gitDefaultBranch = "prime";
    sshAuthorizedKeys = rrvshSshAuthorizedKeys;
  };
  binmohm = {
    name = "binmohm";
    fullName = "binmohm";
    email = "rafiq@rrv.sh";
    uid = 502;
    sshAuthorizedKeys = rrvshSshAuthorizedKeys;
  };
in
{
  config.flake.hosts.darwin = {
    alpha = {
      hostPlatform = "aarch64-darwin";
      primaryUser = rafiq;
      profiles = [
        "graphical"
        "development"
      ];
      modules = [
        cfg.modules.darwin.user-primary
        cfg.modules.darwin.rosetta-builder
      ];
    };
    auto = {
      hostPlatform = "aarch64-darwin";
      primaryUser = binmohm;
      profiles = [
        "development"
        "graphical"
      ];
      modules = [
        cfg.modules.darwin.user-primary
        cfg.modules.darwin.sudo-env-wrapper
        cfg.modules.darwin.claude-code
        {
          home-manager.sharedModules = [
            {
              programs.pi-coding-agent.settings = {
                defaultProvider = "claude-bridge";
                defaultModel = "claude-sonnet-4-6";
              };
              programs.mcp = {
                enable = true;
                servers.atlassian-mcp.url = "https://mcp.atlassian.com/v1/mcp";
              };
            }
          ];
        }
      ];
    };
  };
  config.flake.hosts.nixos = {
    nemesis = {
      hostPlatform = "x86_64-linux";
      primaryUser = rafiq;
      profiles = [
        "graphical"
        "development"
      ];
      modules = [
        cfg.modules.nixos.user-primary
        cfg.modules.nixos.nvidia-graphics
        cfg.modules.nixos.steam
        cfg.modules.nixos.prismlauncher
        cfg.modules.nixos.gtnh-server
        cfg.modules.nixos.gtnh-backups
        (
          {
            config,
            pkgs,
            lib,
            modulesPath,
            ...
          }:
          {
            imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
            hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
            boot = {
              initrd.availableKernelModules = [
                "nvme"
                "xhci_pci"
                "ahci"
                "usbhid"
                "usb_storage"
                "sd_mod"
              ];
              kernelModules = [ "kvm-amd" ];
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
            fileSystems = {
              "/" = {
                device = "/dev/disk/by-uuid/13ad8c18-69ff-4288-8dec-bc50f0f5374c";
                fsType = "ext4";
              };
              "/boot" = {
                device = "/dev/disk/by-uuid/BC86-01BB";
                fsType = "vfat";
                options = [
                  "fmask=0077"
                  "dmask=0077"
                ];
              };
              "/mnt/windows" = {
                device = "/dev/disk/by-uuid/0EA45F71A45F59F3";
                fsType = "ntfs3";
                options = [
                  "rw"
                  "uid=1000"
                  "umask=022"
                  "iocharset=utf8"
                  "windows_names"
                  "nofail"
                  "x-systemd.automount"
                  "x-systemd.idle-timeout=10min"
                ];
              };
            };
          }
        )
      ];
    };
    orichalcum = {
      hostPlatform = "x86_64-linux";
      primaryUser = rafiq;
      modules = [
        cfg.modules.nixos.user-config
        (
          {
            modulesPath,
            pkgs,
            ...
          }:
          {
            imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
            boot = {
              initrd = {
                availableKernelModules = [
                  "ata_piix"
                  "uhci_hcd"
                  "xen_blkfront"
                  "vmw_pvscsi"
                ];
                kernelModules = [ "nvme" ];
                systemd.enable = false;
              };
              loader = {
                efi.efiSysMountPoint = "/boot/efi";
                grub = {
                  efiSupport = true;
                  efiInstallAsRemovable = true;
                  device = "nodev";
                };
              };
            };
            fileSystems = {
              "/" = {
                device = "/dev/vda2";
                fsType = "ext4";
              };
              "/boot/efi" = {
                device = "/dev/disk/by-uuid/F558-B6A7";
                fsType = "vfat";
              };
            };
            swapDevices = [ { device = "/swapfile"; } ];
            networking.firewall.allowedTCPPorts = [
              22
              80
              443
            ];
            virtualisation = {
              podman.enable = true;
              oci-containers = {
                backend = "podman";
                containers.otterwiki-old = {
                  image = "redimp/otterwiki:2-slim";
                  ports = [ "127.0.0.1:18080:8080" ];
                  volumes = [ "/var/lib/otterwiki-old/app-data:/app-data" ];
                  environment = {
                    ATTACHMENT_ACCESS = "ADMIN";
                    DISABLE_REGISTRATION = "True";
                    READ_ACCESS = "ANONYMOUS";
                    SERVER_NAME = "old.aenyrathia.wiki";
                    SITE_DESCRIPTION = "Archived Aenyrathia OtterWiki";
                    SITE_NAME = "Aenyrathia Archive";
                    WRITE_ACCESS = "ADMIN";
                  };
                };
              };
            };
            systemd.tmpfiles.rules = [
              "d /var/lib/otterwiki-old/app-data 0750 33 33 -"
            ];
            users = {
              groups.aenyrathia = { };
              users.aenyrathia = {
                isSystemUser = true;
                group = "aenyrathia";
                home = "/var/lib/aenyrathia";
                createHome = true;
              };
            };
            system.activationScripts.aenyrathia-deploy-key = {
              deps = [ "users" ];
              text = ''
                set -eu
                install -d -m 0750 -o aenyrathia -g aenyrathia /var/lib/aenyrathia
                install -d -m 0700 -o aenyrathia -g aenyrathia /var/lib/aenyrathia/.ssh
                if [ ! -e /var/lib/aenyrathia/.ssh/id_ed25519 ]; then
                  ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -C orichalcum-aenyrathia -f /var/lib/aenyrathia/.ssh/id_ed25519
                fi
                chown aenyrathia:aenyrathia /var/lib/aenyrathia/.ssh/id_ed25519 /var/lib/aenyrathia/.ssh/id_ed25519.pub
                chmod 0600 /var/lib/aenyrathia/.ssh/id_ed25519
                chmod 0644 /var/lib/aenyrathia/.ssh/id_ed25519.pub
                known_hosts=$(mktemp)
                cat > "$known_hosts" <<'KNOWN_HOSTS'
                github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
                github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
                github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
                KNOWN_HOSTS
                install -m 0644 -o aenyrathia -g aenyrathia "$known_hosts" /var/lib/aenyrathia/.ssh/known_hosts
                rm -f "$known_hosts"
              '';
            };
            security.acme = {
              acceptTerms = true;
              defaults.email = "rafiq@rrv.sh";
            };
            services.nginx = {
              enable = true;
              recommendedGzipSettings = true;
              recommendedOptimisation = true;
              recommendedProxySettings = true;
              recommendedTlsSettings = true;
              virtualHosts = {
                "_" = {
                  default = true;
                  rejectSSL = true;
                  locations."/".return = "404";
                };
                "aenyrathia.wiki" = {
                  enableACME = true;
                  forceSSL = true;
                  locations."/".proxyPass = "http://127.0.0.1:3001";
                };
                "old.aenyrathia.wiki" = {
                  enableACME = true;
                  forceSSL = true;
                  locations."/" = {
                    proxyPass = "http://127.0.0.1:18080";
                    extraConfig = ''
                      client_max_body_size 64M;
                    '';
                  };
                };
              };
            };
            systemd.services.aenyrathia = {
              description = "Aenyrathia wiki";
              wantedBy = [ "multi-user.target" ];
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];
              environment = {
                COOKIE_SECURE = "true";
                DATABASE_URL = "sqlite:///var/lib/aenyrathia/aenyrathia.sqlite3";
                GIT_REMOTE = "git@github.com:rrvsh/aenyrathia.git";
                GIT_SSH_KEY_PATH = "/var/lib/aenyrathia/.ssh/id_ed25519";
                HOST = "127.0.0.1";
                PB_LOG = "info";
                PORT = "3001";
              };
              serviceConfig = {
                User = "aenyrathia";
                Group = "aenyrathia";
                ExecStart = "${
                  inputs.aenyrathia.packages.${pkgs.stdenv.hostPlatform.system}.aenyrathia
                }/bin/aenyrathia";
                Restart = "always";
                RestartSec = "5s";
                StateDirectory = "aenyrathia";
                WorkingDirectory = "/var/lib/aenyrathia";
              };
            };
          }
        )
      ];
    };
    hermes = {
      hostPlatform = "x86_64-linux";
      primaryUser = rafiq;
      modules = [
        cfg.modules.nixos.user-config
        (
          {
            config,
            lib,
            pkgs,
            modulesPath,
            ...
          }:
          {
            imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
            hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
            boot = {
              kernelParams = [
                "console=ttyS1,115200n8"
                "console=tty0"
              ];
              # Vultr boots reliably from the UEFI fallback path, so use GRUB's removable EFI install
              # instead of relying on mutable EFI NVRAM entries like a local workstation can.
              loader = {
                efi = {
                  canTouchEfiVariables = false;
                  efiSysMountPoint = "/boot/efi";
                };
                grub = {
                  enable = true;
                  device = "nodev";
                  efiSupport = true;
                  efiInstallAsRemovable = true;
                  useOSProber = false;
                };
              };
            };
            fileSystems = {
              "/" = {
                device = "/dev/disk/by-uuid/cb9f37af-53d2-4510-b513-a8f8c2486445";
                fsType = "ext4";
              };
              "/boot/efi" = {
                device = "/dev/disk/by-uuid/D7A0-0D7E";
                fsType = "vfat";
              };
            };
            swapDevices = [ { device = "/swapfile"; } ];
            networking.firewall.allowedTCPPorts = [
              22
              80
              443
            ];
            security.acme = {
              acceptTerms = true;
              defaults.email = "rafiq@rrv.sh";
            };
            services.nginx = {
              enable = true;
              recommendedGzipSettings = true;
              recommendedOptimisation = true;
              recommendedProxySettings = true;
              recommendedTlsSettings = true;
              virtualHosts."rrv.sh" = {
                enableACME = true;
                forceSSL = true;
                locations."/".proxyPass = "http://127.0.0.1:8080";
              };
            };
            users = {
              groups.site = { };
              users.site = {
                isSystemUser = true;
                group = "site";
                home = "/var/lib/site";
              };
            };
            systemd.services.site = {
              description = "rrv.sh site";
              wantedBy = [ "multi-user.target" ];
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];
              serviceConfig = {
                User = "site";
                Group = "site";
                ExecStart = "${cfg.packages.${pkgs.stdenv.hostPlatform.system}.site-deploy}/bin/site";
                Restart = "always";
                RestartSec = "5s";
                StateDirectory = "site";
                WorkingDirectory = "/var/lib/site";
              };
            };
          }
        )
      ];
    };
  };
}
