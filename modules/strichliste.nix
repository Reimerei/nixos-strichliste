{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    types
    mapAttrs
    mkDefault
    ;
  cfg = config.services.strichliste;
  fpm = config.services.phpfpm.pools.strichliste;
  package = pkgs.strichliste-backend;

  environment = {
    "APP_ENV" = "prod";
    # "APP_SECRET" =
    "DATABASE_URL" = "postgres:///strichliste?host=/run/postgresql";
    "CORS_ALLOW_ORIGIN" = "^https?://localhost(:[0-9]+)?$";
  };
in
{
  options.services.strichliste = {
    enable = mkEnableOption "Access to Memory (AtoM) service";
    domain = mkOption {
      description = "The domain name serving your Strichliste instance.";
      example = "strichliste.example.org";
      type = types.str;
    };
    settings = { };
  };

  config = lib.mkIf cfg.enable {

    services.postgresql = {
      enable = true;
      ensureDatabases = [ "strichliste" ];
      ensureUsers = [
        {
          name = "strichliste";
          ensureDBOwnership = true;
        }
      ];
    };

    users.users.strichliste = {
      isSystemUser = true;
      group = "strichliste";
      home = "/var/lib/strichliste";
      packages = [ package.php ];
    };
    users.groups.strichliste = { };

    systemd.tmpfiles.rules = [
      "d /var/log/strichliste 0755 strichliste strichliste"
      "d /var/cache/strichliste 0755 strichliste strichliste"
    ];

    systemd.services.strichliste-migrate = {
      description = "Strichliste migrations";
      after = [
        "network.target"
        "postgresql.service"
      ];
      path = [
        package.php
      ];
      inherit environment;
      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "strichliste";
        WorkingDirectory = "${package}/share/php/strichliste-backend/";
        User = "strichliste";
        Group = "strichliste";
      };
      script = ''
        php bin/console doctrine:schema:create
      '';
    };

    services.phpfpm.pools.strichliste = {
      user = "strichliste";
      group = "strichliste";
      phpPackage = package.php;
      phpEnv = { };
      settings = {
        "listen.owner" = config.services.nginx.user;
        "listen.group" = config.services.nginx.group;

        "pm" = "dynamic";
        "pm.max_children" = "30";
        "pm.start_servers" = "10";
        "pm.min_spare_servers" = "10";
        "pm.max_spare_servers" = "10";
        "pm.max_requests" = "200";
      };
    };
    systemd.services."phpfpm-strichliste" = {
      after = [
        "postgresql.service"
        "strichliste-migrate.service"
      ];
      requires = [ "strichliste-migrate.service" ];
      inherit environment;
    };

    services.nginx.enable = true;
    # From https://github.com/strichliste/strichliste-backend/blob/master/examples/nginx.conf
    services.nginx.virtualHosts."${cfg.domain}" = {
      root = "${pkgs.strichliste-web-frontend}/lib/node_modules/strichliste-web/public";
      locations = {
        "/".tryFiles = "$uri /index.php$is_args$args";
        "~ ^/index\\.php(/|$)".extraConfig = ''
          fastcgi_split_path_info ^(.+\.php)(/.*)$;
          include ${config.services.nginx.package}/conf/fastcgi.conf;

          fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
          fastcgi_param PATH_INFO $fastcgi_path_info;

          #Avoid sending the security headers twice
          fastcgi_param modHeadersAvailable true;
          fastcgi_param front_controller_active true;
          # fastcgi_pass php-handler;
          fastcgi_intercept_errors on;
          fastcgi_request_buffering off;

          # Prevents URIs that include the front controller. This will 404:
          # http://domain.tld/index.php/some-path
          # Remove the internal directive to allow URIs like this
          internal;
        '';
        "~ \\.php$".extraConfig = "return 404;";
      };
      forceSSL = true;
      enableACME = true;
    };
  };

}
