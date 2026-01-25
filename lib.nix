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
    Collect plugins for a specific Jetbrains IDE, applying the provided overrides configuration.
    
    Works the same as `pluginsForIde`, but with more control over overrides.

    # Type
    ```
    pluginsForIde :: { applyPluginOverrides :: Bool , dontOverride :: [ String ], extraOverrides :: AttrSet of (Derivation -> Derivation)} -> (Nixpkgs instance) -> (String | Derivation) -> [String] -> AttrSet
    ```

    # Inputs
    `applyPluginOverrides` (Bool)
    : Wherether to apply the default plugin overrides.
      Set to false to disable all overrides (even those in `extraOverrides`).

    `dontOverride` (List of String)
    : A list of plugin IDs to not apply the default overrides to.

    `extraOverrides` (AttrSet of (Derivation -> Derivation))
    : A set of additional overrides to apply on top of the default overrides.
      The items must be function that take a plugin derivation and return a modified derivation.

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
  buildPluginsForIdeWith = {
    applyPluginOverrides ? true,
    dontOverride ? [],
    extraOverrides ? {},
  } : pkgs: ide:
    let
      package = resolveIdePackage pkgs ide;
      plugins = (pkgs.callPackage ./plugins.nix { }).${package.pname}.${package.version};
      
      defaultOverrides = pkgs.callPackage ./overrides.nix { };
      
      # Warn if any ids in dontOverride do not exist in defaultOverrides
      checkDontOverride = map (id: pkgs.lib.warnIfNot (defaultOverrides ? id) 
        "Attribute ${id} listed in dontOverride does not exist in defaultOverrides");
      # Warn if any ids in extraOverrides do not exist in plugins
      checkExtraOverridesNotExisting = builtins.mapAttrs (id: pkgs.lib.warnIfNot (plugins ? id)
        "Attribute ${id} listed in extraOverrides does not exist in plugins");
      # Warn if any ids in extraOverrides also exist in dontOverride
      checkExtraOverridesInconsistent = builtins.mapAttrs (id: pkgs.lib.warnIf (builtins.elem dontOverride id)
        "Attribute ${id} listed in extraOverrides also exists in dontOverride, the override will be applied anyway");

      enabledOverrides = removeAttrs defaultOverrides (checkDontOverride dontOverride);
      checkedExtraOverrides = pkgs.lib.pipe extraOverrides [
        checkExtraOverridesNotExisting
        checkExtraOverridesInconsistent
      ];
      mergedOverrides = enabledOverrides // checkedExtraOverrides; # simple overwrite
      finalOverrides = if applyPluginOverrides then mergedOverrides else { };

      getPlugin = id: let
        basePlugin = plugins.${id};
        override = finalOverrides.${id} or pkgs.lib.id;
      in
        override basePlugin;
    in
    genAttrs getPlugin;

  /**
    Collect plugins for a specific Jetbrains IDE.

    Plugins are automatically resolved for the correct IDE, using the IDE's `pname` and `version`.

    Default overrides are automatically applied, use `buildPluginsForIdeWith` for finegrained control.

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
  pluginsForIde = buildPluginsForIdeWith {};

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
    buildPluginsForIdeWith
    ;
}
