{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs,
  yarnConfigHook,
  yarnBuildHook,
  yarnInstallHook,
  fetchYarnDeps,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "strichliste-web-frontend";
  version = "1.7.1";

  src = fetchFromGitHub {
    owner = "strichliste";
    repo = "strichliste-web-frontend";
    tag = "v${finalAttrs.version}";
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
    yarnInstallHook
  ];

  env.NODE_OPTIONS = "--openssl-legacy-provider";

})
