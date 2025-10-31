{
  flake.manifest = {
    externals.nginx = {
      node = "veil";
    };
    nodes.nixos = {
      veil = {
        arch = "aarch64";
        createImage = true;
      };
    };
  };
}
