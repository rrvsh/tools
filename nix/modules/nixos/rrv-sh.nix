{
  flake.modules.nixos.rrv-sh = {
    services.nginx.virtualHosts."rrv.sh" = {
      addSSL = true;
      useACMEHost = "rrv.sh";
      acmeRoot = null; # needed for DNS validation
      #FIXME: Set a global flake root
      locations."/".root = ../../../www/rrv.sh;
    };
  };
}
