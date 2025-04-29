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

      services.strichliste = {
        enable = true;
        domain = "${serverDomain}";
        settings.common.idleTimeout = 123456;
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
      import json

      start_all()
      server.wait_for_unit("phpfpm-strichliste.service")
      client.wait_for_unit("multi-user.target")
      client.succeed("curl --fail https://${serverDomain} | grep Strichliste")

      settings_str = client.succeed("curl --fail https://${serverDomain}/api/settings")
      settings = json.loads(settings_str)["settings"]
      assert settings["common"]["idleTimeout"] == 123456
      assert not settings["paypal"]["enabled"]

      def get_users():
          users_str = client.succeed("curl --fail https://${serverDomain}/api/user")
          return json.loads(users_str)["users"]

      assert get_users() == [];

      test_user = {
        "name": "User",
        "email": "email@acme.com"
      }
      test_user_json = json.dumps(test_user)
      client.succeed(f"curl --fail -X POST -H 'Content-Type: application/json' -d '{test_user_json}' https://${serverDomain}/api/user")

      assert len(get_users()) == 1;

    '';
}
