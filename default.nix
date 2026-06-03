{
  system ? builtins.currentSystem,
  pkgs ? import <nixpkgs> {inherit system;},
}: let
  mypkgs = pkgs.callPackage ./pkgs {};
in
  {
    lib = import ./lib {inherit pkgs;};
    modules = import ./modules;
    pkgs = mypkgs;
  }
  // mypkgs
