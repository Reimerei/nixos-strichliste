{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (builtins)
    toFile
    toJSON
    ;
  inherit (lib)
    mkEnableOption
    mkOption
    types
    mapAttrs
    mkDefault
    getExe
    ;
  cfg = config.services.strichliste;
  fpm = config.services.phpfpm.pools.strichliste;
  dbal = {
    driver = "pdo_pgsql";
    charset = "utf8";
    user = "strichliste";
    dbname = "strichliste";
    host = "/run/postgresql";
  };
  finalPackage = pkgs.strichliste-backend.override { inherit dbal; };

  environment = {
    "APP_ENV" = "prod";
    "APP_SECRET" = "afcb8ed6bf80cf0d8d9196390e06a408"; # TODO
    # "CORS_ALLOW_ORIGIN" = "^https?://${config.services.strichliste.domain}$";
  };
in
{
  options.services.strichliste = {
    enable = mkEnableOption "Strichliste service";
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
      packages = [ finalPackage.php ];
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
        finalPackage.php
      ];
      inherit environment;
      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "strichliste";
        WorkingDirectory = "${finalPackage}/share/php/strichliste-backend/";
        User = "strichliste";
        Group = "strichliste";
      };
      script = ''
        rm -rf /var/cache/strichliste/*
        php bin/console doctrine:schema:create
      '';
    };

    services.phpfpm.pools.strichliste = {
      user = "strichliste";
      group = "strichliste";
      phpPackage = finalPackage.php;
      phpEnv = environment;
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
      restartTriggers = [ finalPackage ];
    };

    services.nginx.enable = true;
    # From https://github.com/strichliste/strichliste-backend/blob/861c954a50f214eaaa6e5dd940f0e98c8349e0a9/contrib/ansible/files/nginx.conf
    services.nginx.virtualHosts."${cfg.domain}" = {
      root = "${pkgs.strichliste-backend}/share/php/strichliste-backend/public/";
      extraConfig = ''
        index index.php;
        client_max_body_size 100m;
      '';
      locations = {
        "/".tryFiles = "$uri $uri/ /index.php$is_args$args";
        "~ \\.php" = {
          tryFiles = "$uri /index.php =404";
          extraConfig = ''
            fastcgi_pass unix:${config.services.phpfpm.pools.strichliste.socket};
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            fastcgi_param SCRIPT_NAME $fastcgi_script_name;
            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_index index.php;
            include ${config.services.nginx.package}/conf/fastcgi.conf;
          '';
        };
      };
      forceSSL = true;
      enableACME = true;
    };
  };

}
