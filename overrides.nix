{
  nodejs,
  delve,
  stdenv,
  lib,
  makeBinaryWrapper,
}:
# This is a list of plugins that need special treatment. For example, the go plugin comes with delve, a
# debugger, but that needs various linking fixes. The changes here replace it with the system one.
{
  "org.jetbrains.plugins.go" =
    plugin:
    plugin.overrideAttrs (old: {
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
    });
  "com.github.copilot" =
    plugin:
    plugin.overrideAttrs (old: {
      # This plugins ships with the language server in binary and js form.
      # The binary form (the default) is very difficult to patch (a patch existed but wasn't stable),
      # so instead we use the js form and wrap it in a binary wrapper that calls nodejs on it.
      nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ makeBinaryWrapper ];
      buildPhase = ''
        agent='copilot-agent/native/${lib.toLower stdenv.hostPlatform.uname.system}${
          {
            x86_64 = "-x64";
            aarch64 = "-arm64";
          }
          .${stdenv.hostPlatform.uname.processor} or ""
        }/copilot-language-server'

        rm -rf $agent
        makeBinaryWrapper ${lib.getExe nodejs} $agent \
          --add-flags "$out/copilot-agent/dist/language-server.js"
      '';
      meta = {
        maintainers = [ "SamueleFacenda" ];
      };
    });
}
