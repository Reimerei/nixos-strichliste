{
  pkgs,
  certs,
  modules,
}:
{ lib, ... }:

let
  serverDomain = certs.domain;
in
{
  name = "strichliste";
  meta.maintainers = with lib.maintainers; [ erictapen ];

  nodes.server =
    { pkgs, lib, ... }:
    {
      imports = modules;

      # virtualisation.memorySize = 4096;
      services.strichliste = {
        enable = true;
        domain = "${serverDomain}";
      };

      services.nginx.virtualHosts."${serverDomain}" = {
        enableACME = lib.mkForce false;
        sslCertificate = certs."${serverDomain}".cert;
        sslCertificateKey = certs."${serverDomain}".key;
      };

      security.pki.certificateFiles = [ certs.ca.cert ];

      networking.hosts."::1" = [ "${serverDomain}" ];
      networking.firewall.allowedTCPPorts = [
        80
        443
      ];
    };

  nodes.client =
    { pkgs, nodes, ... }:
    {
      networking.hosts."${nodes.server.networking.primaryIPAddress}" = [ "${serverDomain}" ];

      security.pki.certificateFiles = [ certs.ca.cert ];
    };

  testScript =
    { nodes }:
    ''
      start_all()
      server.wait_for_unit("phpfpm-strichliste.service")
      client.wait_for_unit("multi-user.target")
      client.succeed("curl --fail https://${serverDomain}")
    '';
}
