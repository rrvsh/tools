{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.nt = pkgs.buildGoModule {
        pname = "nt";
        version = "0.31.0";
        src = inputs.nt;
        subPackages = [ "." ];
        vendorHash = "sha256-nT4fIjXE8e7BPMUp3G0dLLyk5DrOorP86QhKWdC9piY=";
        env.CGO_ENABLED = "0";
        ldflags = [
          "-s"
          "-w"
          "-X main.version=0.31.0"
        ];
        meta = {
          description = "Terminal task and note manager using plain text files";
          homepage = "https://github.com/navbytes/nt";
          license = pkgs.lib.licenses.mit;
          mainProgram = "nt";
        };
      };
    };
}
