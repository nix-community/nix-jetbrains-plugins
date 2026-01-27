{
  lib,
  fetchurl,
  fetchzip,
  stdenv,
  autoPatchelfHook,
}:
with builtins;
with lib;
let
  SEPARATOR = "/--/";

  downloadPlugin =
    {
      name,
      version,
      url,
      hash,
    }:
    let
      isJar = hasSuffix ".jar" url;
      fetcher = if isJar then fetchurl else fetchzip;
    in
    fetcher {
      name = if isJar then "${name}-${version}.jar" else "${name}-${version}";
      executable = isJar;
      inherit url hash;
    };

  readGeneratedDir = attrNames (
    filterAttrs (name: _: hasSuffix ".json" name) (readDir ./generated/ides)
  );

  # Folds into the set of { IDENAME = { VERSION = [ x y ]; }; }
  buildIdeVersionMap = (
    accu: value:
    accu
    // {
      "${value.version}" = (accu."${value.version}" or { }) // value.value;
    }
  );

  # Find and construct plugin from a list of plugins
  findPlugin =
    pluginList: name: version:
    let
      key = "${name}${SEPARATOR}${version}";
      match = pluginList."${key}";
    in
    {
      inherit name version;
      url = "https://downloads.marketplace.jetbrains.com/${match.p}";
      hash = "sha256-${match.h}";
    };

  allPlugins = fromJSON (readFile ./generated/all_plugins.json);
  
  mkPlugin = {name, version, url, ...}@downloadInfo:
    let
      src = downloadPlugin downloadInfo;
      isJar = hasSuffix ".jar" url;
    in
      if isJar 
      then src
      else stdenv.mkDerivation {
        pname = name;
        inherit version src;
        nativeBuildInputs = lib.optional stdenv.hostPlatform.isLinux autoPatchelfHook;
        buildInputs = [ (lib.getLib stdenv.cc.cc) ];
        installPhase = ''
          runHook preInstall
          mkdir -p $out && cp -r . $out
          runHook postInstall
        '';
        buildPhase = ''
          runHook preBuild
          # Make executables in the bin directory executable
          [ -d bin ] && chmod +x -R bin
          runHook postBuild
        '';
      };

  pluginsGrouped = (
    groupBy' buildIdeVersionMap { } (x: x.ideName) (
      map (
        jsonFile:
        let
          # Split the JSON filename into IDENAME-VERSION and remove json suffix
          parts = splitString "-" (removeSuffix ".json" jsonFile);
        in
        {
          ideName = concatStrings (intersperse "-" (init parts));
          version = elemAt parts ((length parts) - 1);
          value = mapAttrs (k: v: mkPlugin (findPlugin allPlugins k v)) (
            fromJSON (readFile (./generated/ides + "/${jsonFile}"))
          );
        }
      ) readGeneratedDir
    )
  );
in
# Add aliases for -oss and the deprecated -community and -ultimate
pluginsGrouped
// {
  idea-community = pluginsGrouped.idea;
  idea-ultimate = pluginsGrouped.idea;
  idea-oss = pluginsGrouped.idea;
  pycharm-community = pluginsGrouped.pycharm;
  pycharm-professional = pluginsGrouped.pycharm;
  pycharm-oss = pluginsGrouped.pycharm;
}
