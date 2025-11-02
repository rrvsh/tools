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
}
