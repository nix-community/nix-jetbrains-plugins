{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.systems.follows = "systems";
    systems.url = "github:nix-systems/default";
    flake-compat.url = "github:NixOS/flake-compat";
    flake-compat.flake = false;
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
      flake-utils,
      ...
    }:
    let
      perSystem = flake-utils.lib.eachSystem (import systems) (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };
        in
        {
          plugins = pkgs.callPackage ./plugins.nix { };

          packages = {
            _nix-jebrains-plugins-generator = pkgs.callPackage ./generator/pkg.nix { };
          };

          devShells = {
            default = pkgs.callPackage ./dev.nix { };
          };

          lib = {
            /**
              Wraps a Jetbrains IDE with the specified plugins from this flake.

              Plugins are automatically resolved against the IDE, using its `pname` and `version`.

              See README.

              # Type
              ```
              buildIdeWithPlugins :: (Jetbrains package set) -> (String | Derivation) -> [String] -> Derivation
              ```

              # Inputs
              `jetbrains` (`pkgs.jetbrains` set)
              : The Jetbrains package set from Nixpkgs.

              `ide` (String or Derivation)
              : The Jetbrains IDE to use.
                If a string is supplied, it is resolved to a `jetbrains` package.

              `pluginIds` (List of String)
              : A list of Jetbrains plugin IDs to use.
                Plugin IDs can be found at the bottom of the plugin's homepage.

              # Output

              A derivation wrapping `ide` along with the specified plugins.
            */
            buildIdeWithPlugins =
              nixpkgs.lib.warn
                "nix-jetbrains-plugins: `lib.${system}.buildIdeWithPlugins` is deprecated. Please switch to `lib.buildIdeWithPlugins`."
                (jetbrains: self.lib.buildIdeWithPlugins (pkgs // { inherit jetbrains; }));
          };
        }
      );
    in
    perSystem
    // {
      lib = import ./lib.nix // perSystem.lib;
    };
}
