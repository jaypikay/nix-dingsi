{pkgs, ...}: {
  stash = pkgs.callPackage ./stash/package.nix {};
}
