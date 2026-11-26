{ inputs, ... }:
{
  config.flake.modules.nixos.unkernel =
    { config, ... }:
    {
      imports = [ inputs.unkernel.nixosModules.default ];

      services.unkernel = {
        enable = true;
        publicUrl = "https://mercury.tail26e972.ts.net";
        wisp.enable = true;
        instances.shell = { };
      };

      systemd.services.tailscale-serve-unkernel = {
        description = "Expose unkernel through Tailscale HTTPS";
        wantedBy = [ "multi-user.target" ];
        after = [
          "tailscaled.service"
          "unkernel-web.service"
        ];
        wants = [
          "tailscaled.service"
          "unkernel-web.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${config.services.tailscale.package}/bin/tailscale serve --bg --yes http://127.0.0.1:8080";
          ExecStop = "${config.services.tailscale.package}/bin/tailscale serve reset";
          RemainAfterExit = true;
        };
      };
    };
}
