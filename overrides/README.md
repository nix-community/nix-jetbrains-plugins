## Plugin overrides

This directory contains the overrides for plugins that need special treatment. 

Each directory here needs to match the ID of a plugin. It must contain a `default.nix`,
which is the entrypoint for the plugin. See any of the existing overrides for reference.

Simply adding a new directory with `default.nix` will make it available.