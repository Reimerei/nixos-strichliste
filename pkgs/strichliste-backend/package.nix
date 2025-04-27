{
  lib,
  applyPatches,
  php81,
  fetchFromGitHub,
  yq,
  # The Database Abstraction Layer configuration for the doctrine ORM
  dbal ? null,
}:
let
  inherit (lib) optionalString;
  php = php81;
  src = applyPatches {
    src = fetchFromGitHub {
      owner = "strichliste";
      repo = "strichliste-backend";
      # tag = "v${finalAttrs.version}";
      rev = "861c954a50f214eaaa6e5dd940f0e98c8349e0a9";
      # hash = "sha256-BlV7tynQKM2rEmnGjO4NuiutBVMDuT4di2oJjdz2suU=";
      hash = "sha256-mMubUzyPZ0AWw8XuHJwIDGtsp1YkxEfsNwDJD5OIEig=";
    };
    patches = [
      ./composer.json.patch
      ./Kernel.php.patch
    ];
  };
in
php.buildComposerProject (finalAttrs: {
  pname = "strichliste-backend";
  version = "1.8.2";
  inherit src;

  postPatch = optionalString (!isNull dbal) ''
    TEMP=$(mktemp)
    echo '${(builtins.toJSON dbal)}'
    set -x
    ${lib.getExe yq} '.doctrine.dbal = ${builtins.toJSON dbal}' config/packages/doctrine.yaml > $TEMP
    mv $TEMP config/packages/doctrine.yaml
  '';

  vendorHash = "sha256-GKf7Sy655c1L0+cLhf81MsJm0v0NEXc9GRwIzeccrPw=";

  passthru = { inherit php; };

  meta = {
    description = "Manage your kiosk in a breeze";
    homepage = "https://www.strichliste.org/";
    license = with lib.licenses; [ mit ];
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ erictapen ];
  };

})
