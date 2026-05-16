{
  delve,
  stdenv,
}:
origPlugin:
origPlugin.overrideAttrs (old: {
  buildInputs = [ delve ];
  buildPhase =
    let
      arch =
        (if stdenv.hostPlatform.isLinux then "linux" else "mac")
        + (if stdenv.hostPlatform.isAarch64 then "arm" else "");
    in
    ''
      runHook preBuild
      ln -sf ${delve}/bin/dlv lib/dlv/${arch}/dlv
      runHook postBuild
    '';
  meta = {
    maintainers = [ "SamueleFacenda" ];
  };
})
