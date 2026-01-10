let
  inherit (builtins)
    attrValues
    isString
    listToAttrs
    ;

  /**
    Generate an attribute set by mapping a function over a list of attribute names.

    Equivalent to `lib.genAttrs` from Nixpkgs, but with flipped arguments.

    # Type
    ```
    genAttrs :: (String -> Any) -> [String] -> AttrSet
    ```
  */
  genAttrs =
    apply: names:
    listToAttrs (
      map (name: {
        inherit name;
        value = apply name;
      }) names
    );

  /**
    Normalises an IDE to a derivation from `pkgs`.

    When supplied with a string, `pkgs.jetbrains.${ide}` is returned.
    Otherwise, `ide` is assumed to be a derivation and is returned unmodified.
  */
  resolveIdePackage = pkgs: ide: if isString ide then pkgs.jetbrains.${ide} else ide;

  /**
    Collect plugins for a specific Jetbrains IDE.

    Plugins are automatically resolved for the correct IDE, using the IDE's `pname` and `version`.

    # Type
    ```
    pluginsForIde :: (Nixpkgs instance) -> (String | Derivation) -> [String] -> AttrSet
    ```

    # Inputs
    `pkgs` (Nixpkgs instance)
    : The package set used for resolving `ide` and building plugins.

    `ide` (String or Derivation)
    : The Jetbrains IDE for which to resolve plugins.
      If a string is supplied, it is resolved to a `pkgs.jetbrains` package.

    `pluginIds` (List of String)
    : A list of Jetbrains plugin IDs to resolve.
      Plugin IDs can be found at the bottom of the plugin's homepage.

    # Output

    A set of plugin derivations.
    Attribute names are the plugin IDs.
  */
  pluginsForIde =
    pkgs: ide:
    let
      package = resolveIdePackage pkgs ide;
      plugins = (pkgs.callPackage ./plugins.nix { }).${package.pname}.${package.version};
    in
    genAttrs (id: plugins.${id});

  /**
    Wraps a Jetbrains IDE with the specified plugins from this flake.

    Plugins are automatically resolved against the IDE, using its `pname` and `version`.

    See README.

    # Type
    ```
    buildIdeWithPlugins :: (Nixpkgs instance) -> (String | Derivation) -> [String] -> Derivation
    ```

    # Inputs
    `pkgs` (Nixpkgs instance)
    : The package set used for resolving `ide` and building plugins.

    `ide` (String or Derivation)
    : The Jetbrains IDE to use.
      If a string is supplied, it is resolved to a `pkgs.jetbrains` package.

    `pluginIds` (List of String)
    : A list of Jetbrains plugin IDs to use.
      Plugin IDs can be found at the bottom of the plugin's homepage.

    # Output

    A derivation wrapping `ide` along with the specified plugins.
  */
  buildIdeWithPlugins =
    pkgs: ide: pluginIds:
    pkgs.jetbrains.plugins.addPlugins (resolveIdePackage pkgs ide) (
      attrValues (pluginsForIde pkgs ide pluginIds)
    );
in
{
  inherit
    pluginsForIde
    buildIdeWithPlugins
    ;
}
