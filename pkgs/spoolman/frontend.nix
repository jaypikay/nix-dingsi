{ buildNpmPackage, callPackage }:
let
  common = callPackage ./common.nix { };
in

buildNpmPackage {
  pname = "spoolman-frontend";

  inherit (common) version;

  src = "${common.src}/client";

  npmDepsHash = "sha256-FcIfO5d5atxoa0VM09apfPAHc+UCR0BMiLSxCfGPcxQ=";

  VITE_APIURL = "/api/v1";

  installPhase = "cp -r dist $out";

  meta = common.meta // {
    description = "Spoolman legacy (React) frontend";
    mainProgram = "spoolman-frontend";
  };
}
