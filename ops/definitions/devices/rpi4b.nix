{
  disko.devices = {
    disk.main = {
      device = "/dev"; # FIXME: set to rpi device name
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

}
