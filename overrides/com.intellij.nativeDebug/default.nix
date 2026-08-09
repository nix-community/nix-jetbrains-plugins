{
  stdenv,
  lib,
  lldb,
}:
origPlugin:
origPlugin.overrideAttrs (old: {
  buildInputs = old.buildInputs or [ ] ++ lib.optionals stdenv.hostPlatform.isLinux [ lldb ];

  meta.maintainers = [ "provokateurin" ];
})
