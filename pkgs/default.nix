{
  system,
  lib,
  pkgs,
  ...
}:
with lib; let
  inherit (pkgs) callPackage;

  stash = callPackage ./stash {};
in
  rec {
  }
  // optionalAttrs (!hasSuffix "-darwin" system) rec {
  }
