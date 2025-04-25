{
  lib,
  applyPatches,
  php81,
  fetchFromGitHub,
}:
let
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
    patches = [ ./composer.json.patch ./Kernel.php.patch ];
  };
in
php.buildComposerProject (finalAttrs: {
  pname = "strichliste-backend";
  version = "1.8.2";
  inherit src;

  vendorHash = "sha256-GKf7Sy655c1L0+cLhf81MsJm0v0NEXc9GRwIzeccrPw=";

  passthru = { inherit php; };

  meta = with lib; {
    description = "Manage your kiosk in a breeze";
    homepage = "https://www.strichliste.org/";
    license = with licenses; [ mit ];
    platforms = platforms.linux;
    maintainers = with maintainers; [ erictapen ];
  };

})
