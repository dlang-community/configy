/*******************************************************************************

    Backend to look up configuration values in command-line arguments

    This backend implements a convention to read values for configuration
    entries using a command-line convention. The default usage in Configy is
    to provide them via `-O`, e.g. `-O foo.bar.value=42`. For a different
    convention, one may extend this backend to their own needs.

*******************************************************************************/

module configy.backend.arguments;

import configy.backend.keyvalue;

/// This struct simply acts as a namespace to simplify importing multiple backends
public struct ArgumentBackend {
    /***************************************************************************

        Get a mapping representing the list of command-line overrides

        The returned value is a `Mapping` that will represent values in the
        configuration.

        Params:
          args = The list of overrides that have been provided via CLI

        Returns:
          The root node for the argument backend, as a `Mapping`.

    ***************************************************************************/

    public static KeyValueMapping make (const string[][string] args) @safe pure nothrow {
        return new KeyValueMapping(null, args, '.');
    }
}
