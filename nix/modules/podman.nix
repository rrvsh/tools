{
  config.flake.modules.nixos.podman = {
    virtualisation = {
      podman.enable = true;
      oci-containers.backend = "podman";
    };
  };
}
