{ inputs, ... }:
{
  imports = [ inputs.disko.flakeModules.default ];
  flake.diskoConfigurations.rpi4b =
    {
      device ? "",
      ...
    }:
    {
      disko.devices = {
        disk.main = {
          inherit device;
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              firmware = {
                type = "EF00";
                size = "64M";
                label = "FIRMWARE";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot/firmware";
                };
              };
              root = {
                type = "8300";
                size = "100%";
                label = "NIXOS_SD";
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/";
                  mountOptions = [ "noatime" ]; # disables access-time updates — improves SD card lifespan
                };
              };
            };
          };
        };
      };
    };
  flake.diskoConfigurations.desktop =
    {
      device ? "",
      ...
    }:
    {
      disko.devices.disk.main = {
        inherit device;
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              name = "boot";
              size = "1M";
              type = "EF02";
            };
            esp = {
              name = "ESP";
              size = "500M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            swap = {
              size = "4G";
              content = {
                type = "swap";
                resumeDevice = true;
              };
            };
            root = {
              name = "root";
              size = "100%";
              content = {
                type = "lvm_pv";
                vg = "root_vg";
              };
            };
          };
        };
      };
      disko.devices.lvm_vg.root_vg = {
        type = "lvm_vg";
        lvs.root = {
          size = "100%FREE";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            subvolumes = {
              "/root".mountpoint = "/";
              "/persist" = {
                mountpoint = "/persist";
                mountOptions = [
                  "subvol=persist"
                  "noatime"
                ];
              };
              "/nix" = {
                mountpoint = "/nix";
                mountOptions = [
                  "subvol=nix"
                  "noatime"
                ];
              };
            };
          };
        };
      };
    };
}
