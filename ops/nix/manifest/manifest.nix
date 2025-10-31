{
  flake.manifest = {
    nodes.nixos = {
      veil = {
        arch = "aarch64";
        createImage = true;
      };
    };
  };
}
