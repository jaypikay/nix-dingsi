{pkgs, ...}: {
  stash = pkgs.callPackage ./stash/package.nix {};
  whisparr = pkgs.callPackage ./whisparr/package.nix {};
}
