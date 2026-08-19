{ inputs, ... }:
{
  config.flake.modules.nixos.hermes-agent =
    { lib, pkgs, ... }:
    let
      hardening = {
        AmbientCapabilities = "";
        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryMax = "3G";
        PrivateDevices = true;
        ProtectControlGroups = true;
        ProtectHome = false;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        TasksMax = 512;
      };
    in
    {
      imports = [ inputs.hermes-agent.nixosModules.default ];
      services.hermes-agent = {
        enable = true;
        addToSystemPackages = true;
        package = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.minimal;
        backend.mode = "none";
        user = "rafiq";
        group = "users";
        createUser = false;
        extraPackages = with pkgs; [
          curl
          jq
          openssh
          ripgrep
        ];
      };
      systemd.services.hermes-agent = {
        environment.HOME = lib.mkForce "/home/rafiq";
        serviceConfig = hardening // {
          ReadWritePaths = lib.mkForce [
            "/var/lib/hermes"
            "/home/rafiq"
          ];
        };
      };
    };
}
