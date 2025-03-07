/*******************************************************************************

    Backend to look up configuration values in environment variables

    This backend implement a convention to map configuration values to
    environment variables. It is much more limited than other backend due to
    the fact that environment variables are simply key/value strings.

    The backend expects a prefix to be used, to avoid configuration values
    being pulled from unexpected places for very generic name. For example,
    if there is a `home` scalar at the top level, that would pull `$HOME`
    without a prefix, while the user probably intends to use `MYAPP_HOME`.

    Scalar are easily represented as environment variables are strings. However,
    hierarchy (and hence mapping) is usually denoted by separating keys with
    an underscore. For example, the following configuration:
    ```
    struct User { string name; }
    struct Config {
      User user;
    }
    ```
    will map to the environment variable (assuming `CONFIGY` prefix):
    `CONFIGY_USER_NAME`. Sequences currently are not supported.

*******************************************************************************/

module configy.backend.environment;

import configy.backend.keyvalue;

/// This struct simply acts as a namespace to simplify importing multiple backends
public struct EnvironmentBackend {
    import std.process;

    /***************************************************************************

        Get a mapping representing the environment

        The returned value is a `Mapping` that will represent values in the
        environment. Changes to the environment will not be picked up. If a
        prefix is provided (recommended), only values matching the prefix will
        be taken into account.

        Params:
          prefix = If present, the prefix will be used by Configy as a top level
                   namespace. For example, if `MYAPP` is provided, and the
                   config has a nested `foo` struct with a `bar` field, Configy
                   will look for `MYAPP_FOO_BAR`, whether with an empty prefix
                   it will simply look for `FOO_BAR`. It is recommended to use
                   a prefix whenever possible.
          env = The environment to use. If not provided,
                `std.process : environment` will be used.

        Returns:
          The root node for the environment, as a `Mapping`.

    ***************************************************************************/

    public static KeyValueMapping make (string prefix, const string[string] env = environment.toAA())
         @safe pure nothrow {
        prefix = prefix.length ? (prefix ~ '_') : null;
        return new KeyValueMapping(prefix, env, '_');
    }
}
