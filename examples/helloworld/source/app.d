module helloworld;

import agora.config.Config;

import std.getopt;
import std.stdio;
import std.typecons;
import core.thread;

struct Config
{
    /// The name to greet
    string name;

    /// Other people to greet
    SetInfo!(string[]) extra_names;

    /// How often to greet the user
    Duration frequency = 1.seconds;

    /// How many times should we repeat the greeting (0: no limit)
    @Optional size_t limit;
}

int main (string[] args)
{
    // `parseConfigSimple` will print to `stderr` if an error happened
    Nullable!Config configN = parseConfigFileSimple!Config("config.yaml");
    if (configN.isNull())
        return 1;
    auto config = configN.get();

    // Your program goes here
    for (size_t i = 0; config.limit == 0 || i < config.limit; ++i)
    {
        writeln("Hello World to you ", config.name);
        if (config.extra_names.set)
            writefln("And to you too, %-(%s, %)", config.extra_names.value);
        Thread.sleep(config.frequency);
    }

    return 0;
}
