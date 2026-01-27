{
  nodejs,
  delve,
  stdenv,
  lib,
  glibc,
  gcc-unwrapped,
}:
# This is a list of plugins that need special treatment. For example, the go plugin comes with delve, a
# debugger, but that needs various linking fixes. The changes here replace it with the system one.
{
  "org.jetbrains.plugins.go" = plugin: plugin.overrideAttrs (old: {
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
      minVersionTested = "252.27397.103";
      maxVersionTested = "252.27397.103";
    };
  });
  "com.github.copilot" = plugin: plugin.overrideAttrs (old: {
    # This plugins ships with the language server in binary and js form.
    # The binary form (the default) is very difficult to patch (a patch existed but wasn't stable),
    # Removing the binaries triggers the fallback option of loading the js language server.
    propagatedBuildInputs = [ nodejs ];
    buildPhase = ''
      rm -rf copilot-agent/native
    '';
    meta = {
      maintainers = [ "SamueleFacenda" ];
      minVersionTested = "1.5.63-243";
      maxVersionTested = "1.5.63-243";
    };
  });
}
