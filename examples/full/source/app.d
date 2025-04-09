module helloworld;

import configy.easy;

import std.stdio;
import std.typecons;

struct FriendConfig
{
    string name;
    @Optional int age;
}

struct Config
{
    string user;
    SetInfo!int frequency;
    FriendConfig witness;
    FriendConfig[] attendee;
}

int main (string[] clargs)
{
    // This will read `args` (and modify it a la `getopt`), look up `config.yaml`,
    // and the environment using the binary name as prefix.
    CLIArgs args;
    args.parse(clargs);
    Nullable!Config configN = parseAppConfiguration!Config(args);
    if (configN.isNull())
        return 1;
    auto config = configN.get();

    writeln("Configuration: ", config);

    // From environment (`MYAPP_USER`)
    assert(config.user == "John Smith");
    // From the command line
    assert(config.frequency == 42);
    assert(config.frequency.set == true);

    // Name comes from arg, age from env
    assert(config.witness == FriendConfig("Kevin Bacon", 121));

    // From the configuration file
    assert(config.attendee.length == 2);
    assert(config.attendee[0] == FriendConfig("John Doe"));
    assert(config.attendee[1] == FriendConfig("Jany Dirkin", 27));

    assert(clargs == [ "./myapp", "some", "positional", "arguments" ]);

    return 0;
}

private ConfigT parseAppConfiguration (ConfigT) (in CLIArgs args)
{
    import configy.backend.arguments;
    import configy.backend.environment;
    import configy.backend.multi;
    import configy.backend.node;
    import configy.backend.yaml;

    Mapping args_root = ArgumentBackend.make(args.overrides);
    Mapping env_root = EnvironmentBackend.make(`MYAPP`);
    Mapping yaml_root = parseFile(args.config_path);
    scope root = MultiBackend.make([args_root, env_root, yaml_root]);
    return parseConfig!ConfigT(root);
}
