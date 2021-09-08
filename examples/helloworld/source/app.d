module helloworld;

import agora.config.Config;

import std.getopt;
import std.stdio;
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

void main (string[] args)
{
    CLIArgs clargs;
    // This calls `getopt` under the hood, and parses `config|c` and `O|override`
    // This step is *optional* but recommended.
    auto helpInformation = clargs.parse(args);
    if (helpInformation.helpWanted)
    {
        defaultGetoptPrinter("Some information about the program.",
            helpInformation.options);
    }

    // An `Exception` will be thrown if this fails
    auto config = clargs.parseConfigFile!Config;

    for (size_t i = 0; config.limit == 0 || i < config.limit; ++i)
    {
        writeln("Hello World to you ", config.name);
        if (config.extra_names.set)
          writefln("And to you too, %-(%s, %)", config.extra_names.value);
        Thread.sleep(config.frequency);
    }
}
