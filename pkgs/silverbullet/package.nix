{
  autoPatchelfHook,
  common-updater-scripts,
  fetchzip,
  lib,
  nixosTests,
  stdenv,
  stdenvNoCC,
  writeShellScriptBin,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "silverbullet";
  version = "3.0.1";

  src =
    finalAttrs.passthru.sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [autoPatchelfHook];

  buildInputs = [stdenv.cc.cc.lib];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp $src/silverbullet $out/bin/
    runHook postInstall
  '';

  passthru = {
    sources = {
      "x86_64-linux" = fetchzip {
        url = "https://github.com/silverbulletmd/silverbullet/releases/download/${finalAttrs.version}/silverbullet-server-linux-x86_64.zip";
        hash = "sha256-xoDcTfbBKP1OevKn2k+w/19Luf/biya2fDz87Dwygiw=";
        stripRoot = false;
      };
      "aarch64-linux" = fetchzip {
        url = "https://github.com/silverbulletmd/silverbullet/releases/download/${finalAttrs.version}/silverbullet-server-linux-aarch64.zip";
        hash = "sha256-dO+DOfdYocltr2vLnp1V/ovlWaEHKnS0qYq9u+FScnA=";
        stripRoot = false;
      };
      "x86_64-darwin" = fetchzip {
        url = "https://github.com/silverbulletmd/silverbullet/releases/download/${finalAttrs.version}/silverbullet-server-darwin-x86_64.zip";
        hash = "sha256-9Z+GxBiF7hcnrwno00UB1d6KIJcmHfKqS1CKljl5FjE=";
        stripRoot = false;
      };
      "aarch64-darwin" = fetchzip {
        url = "https://github.com/silverbulletmd/silverbullet/releases/download/${finalAttrs.version}/silverbullet-server-darwin-aarch64.zip";
        hash = "sha256-RzmhHBfq3xCl2I7wsvP/gYphsj55P4OwWzIrq1iK4IA=";
        stripRoot = false;
      };
    };

    updateScript = writeShellScriptBin "update-silverbullet" ''
      set -eu
      if [ "$#" -ne 1 ] || [[ ! "$1" =~ ^[0-9A-Za-z][0-9A-Za-z._+-]*$ ]]; then
        echo "Usage: update-silverbullet <new-version>" >&2
        exit 1
      fi

      package=pkgs/silverbullet/package.nix
      if [ ! -f "$package" ]; then
        echo "Run this updater from the repository root." >&2
        exit 1
      fi
      if [ -e "$package.cmp" ] || [ -e silverbullet.fetchlog ]; then
        echo "Remove the existing updater backup or fetch log before running." >&2
        exit 1
      fi

      backup=$(mktemp)
      cp "$package" "$backup"
      cleanup() {
        status=$?
        if [ "$status" -ne 0 ]; then
          cp "$backup" "$package"
          rm -f "$package.cmp" silverbullet.fetchlog
          echo "Update failed; restored $package." >&2
        fi
        rm -f "$backup"
      }
      trap cleanup EXIT

      for platform in ${lib.escapeShellArgs finalAttrs.meta.platforms}; do
        ${lib.getExe' common-updater-scripts "update-source-version"} "silverbullet" "$1" --ignore-same-version --file="$package" --source-key="sources.$platform"
      done
    '';

    tests = {
      inherit (nixosTests) silverbullet;
    };
  };

  meta = {
    changelog = "https://github.com/silverbulletmd/silverbullet/blob/${finalAttrs.version}/website/CHANGELOG.md";
    description = "Open-source, self-hosted, offline-capable Personal Knowledge Management (PKM) web application";
    homepage = "https://silverbullet.md";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [aorith];
    mainProgram = "silverbullet";
    platforms = builtins.attrNames finalAttrs.passthru.sources;
  };
})
