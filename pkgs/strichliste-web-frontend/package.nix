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
  version = "1.7.1-unstable";

  src = fetchFromGitHub {
    owner = "strichliste";
    repo = "strichliste-web-frontend";
    # recent master
    rev = "05c3611d614bf9a41f3c1ac8cf0d53a94bf6712b";
    hash = "sha256-KpnKz0Iv7Z57SUv4eai/PVOyGK7Lw1WkuzjUjybyCCk=";
  };

  offlineCache = fetchYarnDeps {
    yarnLock = "${finalAttrs.src}/yarn.lock";
    hash = "sha256-f9Vv+aJ5gFMuLxwOPhFFKjdnE7i/i0Sp0BjFka7nDtE=";
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
