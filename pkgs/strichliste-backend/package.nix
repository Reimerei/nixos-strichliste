{
  lib,
  applyPatches,
  php81,
  fetchFromGitHub,
  yq,
  strichliste-web-frontend,
  # The Database Abstraction Layer configuration for the doctrine ORM
  dbal ? null,
  # Strichliste settings
  settings ? { },
}:
let
  inherit (builtins) toFile toJSON;
  inherit (lib) optionalString getExe;
  php = php81;
  version = "1.8.2";
  src = applyPatches {
    src = fetchFromGitHub {
      owner = "strichliste";
      repo = "strichliste-backend";
      tag = "v${version}";
      hash = "sha256-BlV7tynQKM2rEmnGjO4NuiutBVMDuT4di2oJjdz2suU=";
    };
    patches = [
      # Fixed composer.json and composer.lock so that `composer validate` succeeds
      ./composer.json.patch
      # Put cache and log directory into better places
      ./Kernel.php.patch
    ];
  };
in
php.buildComposerProject {
  pname = "strichliste-backend";
  inherit version src;

  vendorHash = "sha256-GKf7Sy655c1L0+cLhf81MsJm0v0NEXc9GRwIzeccrPw=";

  postPatch =
    let
      settingsExtension = toFile "strichliste.yaml" (toJSON {
        parameters.strichliste = settings;
      });
    in
    ''
      TEMP=$(mktemp)
      # Extend the default settings with custom ones
      ${getExe yq} -s '.[0] * .[1]' config/strichliste.yaml ${settingsExtension} > $TEMP
      mv $TEMP config/strichliste.yaml
      cat config/strichliste.yaml
    ''
    + optionalString (!isNull dbal) ''
      TEMP=$(mktemp)
      # Replace the default database config with a custom one
      ${getExe yq} '.doctrine.dbal = ${toJSON dbal}' config/packages/doctrine.yaml > $TEMP
      mv $TEMP config/packages/doctrine.yaml
    '';

  postInstall = ''
    cp -r ${strichliste-web-frontend}/* $out/share/php/strichliste-backend/public/
  '';

  passthru = { inherit php; };

  meta = {
    description = "Manage your kiosk in a breeze";
    homepage = "https://www.strichliste.org/";
    license = with lib.licenses; [ mit ];
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ erictapen ];
  };

}
