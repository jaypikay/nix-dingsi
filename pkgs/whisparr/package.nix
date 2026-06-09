{
  lib,
  stdenv,
  curl,
  dotnet-runtime,
  fetchurl,
  icu,
  libmediainfo,
  makeWrapper,
  mono,
  openssl,
  sqlite,
  zlib,
  nixosTests,
}: let
  os = "linux";
  system = stdenv.hostPlatform.system;
  arch = "x64";
in
  stdenv.mkDerivation rec {
    pname = "whisparr";
    version = "2.2.0-release.108";

    hash = "sha256-8nJWUmK/qMGMC9rDp0vGXd2WBZ8pqo075WU7emn2Qbs=";

    src = fetchurl {
      url = "https://github.com/Whisparr/Whisparr/releases/download/v${version}/Whisparr.${version}.${os}-${arch}.tar.gz";
      inherit hash;
    };

    nativeBuildInputs = [makeWrapper];

    runtimeLibs = lib.makeLibraryPath [
      curl
      icu
      libmediainfo
      mono
      openssl
      sqlite
      zlib
    ];

    installPhase = ''
      runHook preInstall

      rm -rf "Whisparr.Update"

      mkdir -p $out/{bin,share/${pname}-${version}}
      cp -r * $out/share/${pname}-${version}/

      makeWrapper "${dotnet-runtime}/bin/dotnet" $out/bin/Whisparr \
        --add-flags "$out/share/${pname}-${version}/Whisparr.dll" \
        --prefix LD_LIBRARY_PATH : ${runtimeLibs}

      runHook postInstall
    '';

    passthru = {
      tests.smoke-test = nixosTests.whisparr;
    };

    meta = {
      description = "Adult movie collection manager for Usenet and BitTorrent users";
      homepage = "https://wiki.servarr.com/en/whisparr";
      changelog = "https://whisparr.servarr.com/v1/update/nightly/changes";
      license = lib.licenses.gpl3Only;
      platforms = [
        "x86_64-linux"
      ];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      mainProgram = "Whisparr";
      maintainers = [];
    };
  }
