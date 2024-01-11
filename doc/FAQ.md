# Common patterns while writing configurations

The following list covers common use-case encountered while writing a configuration.

When designing a configuration format, it is usually simpler to write the `struct`s,
and perform any adaptation to make the YAML result nice afterwards.

When multiple ways to handle the same outcome exists, the recipes will list them by order of importance.
For example, when considering having an optional field, first consider giving it an initializer,
and only if the `.init` problem present itself, use `@Optional`.
While the last option, using `SetInfo`, achieves the desired outcome,
it should be avoided unless needed.

## How do I ... ?

### Allow fields in my YAML file that are not present in the `struct` (unknown fields)

By default, the library runs on "strict" mode, and any field found in the document that is
not part of the `struct` definition will result in an error, indicating what fields are
allowed for the section.
This is the default as it prevent any unnoticed misconfiguration that would result from
a typo to an optional field name.
To disable `strict` parsing, simply pass `StrictMode.Ignore` as the optional parameter
to either `parseConfigFile`, `parseConfigString`, or `parseConfigFileSimple` method.
To notify the user whithout triggering an error, use `StrictMode.Warn` instead.

### Make a field required

All fields are required by default, except for `bool` fields, which are always optional.

### Make a field optional

Any field that has an initializer different from its `.init` value is considered optional,
except for `bool` which is always optional.

For example, in the following configuration, `dns` is optional:
```D
struct Config
{
    string dns = "8.8.8.8";
}
```

In some cases, the `.init` value is the desired default value,
in which case `@Optional` can be used:
```D
struct Config
{
    /// Default to 0, unlimited
    @Optional size_t connection_limit;
}
```

Finally, as a byproduct of its functionality, using `SetInfo` implicitly make a field optional.

### Known when a field is set

To know if a field of type `T` is set, use `SetInfo!T` in the field definition.

This can be useful in some special cases:
- Two fields are mutually exclusive but at least one of them is required;
- One or more fields need to have default values, but some extra verification
  needs to be taken if one is set;
- One want to print a better error message when the program fails,
  depending on the configuration that was actually provided by the user
  (e.g. to differentiate a default value from a user-provided value which is identical);

```D
struct Config
{
    /// Use a fixed set of peers
    SetInfo!(string[]) peer_list;

    /// Use a service discovery server
    SetInfo!(string) discovery_server;

    void validate () const
    {
        if (this.peer_list.set && this.discovery_server.set)
            throw new Exception("Both peer_list and discovery_server can't be set at the same time");
        if (!this.peer_list.set && !this.discovery_server.set)
            throw new Exception("Neither peer_list nor discovery_server have been set");
    }
}
```

### Divide my configuration files into logical pieces

Use `struct`s. Any field that is a `struct` is considered as a new section and will be recursed into:

```D
struct Config
{
    GitConfig git;
    SSHConfig ssh = SSHConfig("/usr/bin/ssh");
}

struct GitConfig
{
    string path = "/usr/bin/git";
    @Optional string[] aliases;
}

struct SSHConfig
{
    string path;
    @Optional string[] default_switches;
    string user = "John Doe";
}
```

Sections are just regular fields, and all the approaches mentioned here work whether the
field is a simple `string` or an object.
For example, in the example above, both the `git` and `ssh` sections are optional,
as `GitConfig` is purely optional, and the initializer to the `ssh` field provides
a default value for the required `ssh.path` field.

### Use a keyword, or a different name, in my config file

By default, this library will use the `struct`'s field name for the key name in the YAML file.
Sometimes it is not possible, e.g. when the desired name in the YAML file is a keyword in D.
In this case, one can use the `@Name(string)` UDA:
```D
struct Config
{
    @Name("delegate")
    string delegate_;
}
```

### Have dynamic section names / Turn arrays into objects

With only static names YAML keys, some configurations can become a bit verbose.
A common practice with YAML / JSON is to nest objects inside of objects,
and use the name as a key, for example:
```YAML
interfaces:
  eth0:
    ip: "192.168.0.1"
    private: true
  wlan0:
    ip: "1.2.3.4"
```
This can be achieved with this library without losing type safety,
by recognizing that the above is syntax sugar for the following configuration:
```YAML
  interfaces:
    - name: eth0
      ip: "192.168.0.1"
      private: true
    - name: wlan0
      ip: "1.2.3.4"
```

Using an array and the `@Key(string)` attribute, we can parse the first example:
```D
struct Config
{
    @Key("name")
    InterfaceConfig interfaces;
}

struct InterfaceConfig
{
    string name;
    string ip;
    bool private;
}
```
Removing the `@Key("name")` attribute will instead parse the second example.

### Read durations, such as delays or timeout

Just use `core.time : Duration`, it is natively supported:
```D
import core.time;

struct Config
{
    Duration timeout = 10.seconds;
}
```

In the config file, any of the usual `Duration` units can be used,
as if the `Duration` field was a section:
```YAML
timeout:
  days:     1
  minutes: 10
  seconds: 30
```
The fields are additive, so the timeout in this case is 1 day, 10 minutes and 30 seconds,
or 87030 seconds.

### Implement complex types that are not composite types of simple types

The library recognizes three possible ways were a field of type `T`,
where `T` is a `struct`, can be constructed:
- The `T` has a `static` `fromString` method which accepts a single argument
  that is a string-like type (e.g. `scope const char[]` or just `string`),
  and returns an instance of a type that implicitly converts to `T`;
- `T` has an explicitly-defined constructor that accepts, as a single parameter,
  a string-like type;
- The field has a `@Converter` attribute;

If more than one option exists, the `Converter` will be preferred,
followed by the `fromString` and finally the constructor.
Otherwise, the library will default to field-wise construction.

The recommended way to implement a complex type is to use `fromString`.
For example, the following parses a `SysTime`:
```D
struct Config
{
    TimeConfig time;
}

struct TimeConfig
{
    import std.datetime;

    SysTime time;

    static TimeConfig fromString (string arg)
    {
        return TimeConfig(SysTime.fromSimpleString(arg));
    }
}
```

Which will parse the following YAML file:
```YAML
time: '2010-Dec-22 17:22:01'
```

### Implement validation for a field

The recommended way is to use a type that implement `fromString`,
even if the type is natively supported:
```D
import std.conv;

struct Config
{
    string name;
    Percentage percent;
}

struct Percentage
{
    ubyte value;

    static Percentage fromString (string arg)
    {
        auto v = arg.to!ubyte;
        if (v > 100)
          throw new Exception("Percentage cannot be over 100");
        return Percentage(v);
    }
}
```

The main benefit of using this method is that `Exception` will be caught by
the config parser and re-thrown with field file / line information.
So the above, when provided the following config file:
```YAML
name: "Gary"
percentage: 142
```
Will result in the following error:
```
config.yaml(1:12): percentage: Percentage cannot be over 100
```

**Note**: There is currently an OB1 error in the line number (it should be `(2:12)`),
this bug will need to be fixed in D-YAML.

### Implement validation for a section

If validation of individual fields is not enough and the section as a whole needs
to be validated, one can implement a `void validate() const` method which throws
an exception in the even of a validation failure.
The library will rethrow this `Exception` with the file/line information pointing
to the section itself, and not any individual field.
