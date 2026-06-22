{
  nodejs,
  stdenv,
  lib,
  makeBinaryWrapper,
  autoPatchelfHook,
  libX11,
  libXtst,
  glib,
  pipewire,
  libjpeg8,
  libpng,
  libei,
  libsecret,
}:
origPlugin:
origPlugin.overrideAttrs (old: {
  # This plugins ships with the language server in binary and js form.
  # The binary form (the default) is very difficult to patch (a patch existed but wasn't stable),
  # so instead we use the js form and wrap it in a binary wrapper that calls nodejs on it.
  nativeBuildInputs =
    old.nativeBuildInputs or [ ]
    ++ [ makeBinaryWrapper ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs =
    old.buildInputs or [ ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      libX11
      libXtst
      libjpeg8
      libpng
      pipewire
      glib
      libei
      libsecret
    ];
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

    # unused binaries
    rm copilot-agent/dist/node_modules/@github/copilot/sdk/prebuilds/linuxmusl-*/keytar.node
  '';
  meta = {
    maintainers = [ "SamueleFacenda" ];
  };
})
