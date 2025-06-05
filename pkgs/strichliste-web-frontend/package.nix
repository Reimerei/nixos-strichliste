{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs,
  yarnConfigHook,
  yarnBuildHook,
  fetchYarnDeps,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "strichliste-web-frontend";
  version = "1.7.1";

  src = fetchFromGitHub {
    owner = "strichliste";
    repo = "strichliste-web-frontend";
    tag = "v1.7.1";
    hash = "sha256-r9R//4XE85dkChLSu+Sn8Yo72dNZY8Z3yDHOiYIYjwg=";
  };

  offlineCache = fetchYarnDeps {
    yarnLock = "${finalAttrs.src}/yarn.lock";
    hash = "sha256-NVQpXMiKVgFnAxLvl+BhFqXZU51D2CWfrVs5e/m4bMs=";
  };

  nativeBuildInputs = [
    nodejs
    yarnConfigHook
    yarnBuildHook
  ];

  env.NODE_OPTIONS = "--openssl-legacy-provider";

  installPhase = ''
    runHook preInstall
    cp -r build $out
    runHook postInstall
  '';
})
