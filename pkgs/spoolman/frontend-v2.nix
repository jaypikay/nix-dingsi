{ buildNpmPackage, callPackage }:
let
  common = callPackage ./common.nix { };
in

buildNpmPackage {
  pname = "spoolman-frontend-v2";

  inherit (common) version;

  src = "${common.src}/client_v2";

  npmDepsHash = "sha256-5lla83vzf54fYq1BPfQ7RmBsiHwFgX0os5+ypJlWNMs=";

  # No VITE_APIURL: the new client resolves the API relative to its base path.

  installPhase = "cp -r build $out";

  meta = common.meta // {
    description = "Spoolman frontend (new Svelte client, served by default)";
    mainProgram = "spoolman-frontend-v2";
  };
}
