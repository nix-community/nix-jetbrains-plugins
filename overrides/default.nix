{
  lib,
  callPackage,
}:
# map: <dirname> -> package in <dirname>/default.nix
lib.pipe ./. [
  builtins.readDir
  (lib.mapAttrs (pid: _: ./. + "/${pid}/default.nix"))
  (lib.filterAttrs (_: lib.pathExists))
  (lib.mapAttrs (_: file: callPackage file { }))
]
