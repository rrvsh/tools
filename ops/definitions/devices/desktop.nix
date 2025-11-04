{
  disko.devices.disk.main = {
    device = "/dev/disk/by-id/nvme-CT2000P3SSD8_2325E6E77434";
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
}
