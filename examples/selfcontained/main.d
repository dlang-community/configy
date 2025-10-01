/+ dub.json: {
 "name": "configy-selfcontained",
 "dependencies": {
   "configy": { "path": "../../" }
 }
} +/
/**
 * Self-contained example, template for simple unit-test
 *
 * For remote users, you might want to use `"configy": "~master"` instead
 * for testing, or `"configy": "~>3.0" for production use.
 *
 * From the root of the repository:
 * - dub examples/selfcontained/main.d
 * - dub examples/selfcontained/main.d foo.yml
 */
module selfcontained;

import configy.easy;

import std.stdio;
import std.typecons;

/// Replace the members of this struct with your code
public struct Config
{
    string name;
}

/// Replace the content of this file with your YAML
public immutable string localYAML = `
name: "John Doe"
`;

/// Entrypoint: If files are provided, it will parse and dump them in sequence
/// If none is provided, it will just dump the content of the above YAML.
int main (string[] args) {

    foreach (file; args[1 .. $]) {
        writeln("==================== ", file, " ====================");
        Nullable!Config configN = parseConfigFileSimple!Config(file);
        if (configN.isNull())
            return 1;
        writeln(configN.get());
    }
    // The foreach didn't run
    if (args.length == 1) {
        Nullable!Config configN = wrapException(parseConfigString!Config(localYAML, __FILE__));
        if (configN.isNull())
            return 1;
        writeln(configN.get());
    }
    return 0;
}
