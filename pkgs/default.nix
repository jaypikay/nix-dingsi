{pkgs, ...}: {
  controld-exporter = pkgs.callPackage ./controld-exporter/package.nix {};
  silverbullet = pkgs.callPackage ./silverbullet/package.nix {};
  stash = pkgs.callPackage ./stash/package.nix {};
  whisparr = pkgs.callPackage ./whisparr/package.nix {};
}
