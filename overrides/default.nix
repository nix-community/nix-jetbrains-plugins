{
  lib,
  callPackage,
}:
let
  inherit (builtins) mapAttrs readDir;
in
# map: <dirname> -> package in <dirname>/default.nix
mapAttrs (pid: _: callPackage (./. + "/${pid}/default.nix") { }) (
  lib.filterAttrs (n: v: (v == "directory")) (readDir ./.)
)
