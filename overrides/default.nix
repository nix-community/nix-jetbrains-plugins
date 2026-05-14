{
  lib,
  callPackage,
}:
with builtins;
# map: <dirname> -> package in <dirname>/default.nix
mapAttrs (n: _: callPackage (./. + "/${n}/default.nix") { }) (
  lib.filterAttrs (n: v: (v == "directory")) (readDir ./.)
)
