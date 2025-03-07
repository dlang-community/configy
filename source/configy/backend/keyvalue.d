/*******************************************************************************

    A generic key-value backend to allow associating path to values

    This backend allows translating a path to a key name that can then be
    looked up. It is useful for use case like environment variable or command
    line argument.

*******************************************************************************/

module configy.backend.keyvalue;

import configy.backend.node;

import std.algorithm;
import std.range : takeOne;
import std.uni : icmp, toLower;

/**
 * Represents a mapping over a key-value pair.
 *
 * A mapping is essentially a filter over a list of keys. For example, if the
 * available values are `home.user`, home.address`, `location.altitude`, using
 * the filter `home` will have 2 values in scope, while `location` would have
 * one and `foo` would have none.
 *
 * This also apply to environment variables, where names are usually uppercase
 * and the separator is `_`. This prefix is stored in `KeyValueMapping`, along
 * with the entire list of key-values, which allow us to avoid duplicating
 * (and hence allocating) it for every lookup.
 */
public class KeyValueMapping : Mapping {
    /// The prefix (ending with a separator) that keys must match to
    /// be considered to be in this mapping
    private string prefix;

    /// The separator used for keys
    private char separator;

    /// The entire (unfiltered) list of key-value
    private const string[][string] values;

    /***************************************************************************

        Creates a new KeyValueMapping

        Params:
          prefix = Prefix to apply to this mapping. May be `null`.
          values = The entire list of values to use.
          separator = The separator the applies to `prefix`.

    ***************************************************************************/

    public this (string prefix, const string[][string] values, char separator)
        @safe pure nothrow @nogc {
        this.separator = separator;
        this.values = values;
        this.prefix = prefix;
        assert(!this.prefix.length || this.prefix[$-1] == this.separator);
    }

    /// Ditto
    public this (string prefix, inout const string[][string] values, char separator)
        inout @safe pure nothrow @nogc {
        this.separator = separator;
        this.values = values;
        this.prefix = prefix;
        assert(!this.prefix.length || this.prefix[$-1] == this.separator);
    }

    ///
    public this (string prefix, const string[string] values, char separator)
        @safe pure nothrow {
        import std.array;
        import std.typecons;
        this(prefix, values.byKeyValue.map!(kv => tuple(kv.key, [ kv.value])).assocArray, separator);
    }

    ///
    public size_t length () const scope @safe {
        return this.values.byKey.filter!(k => k.startsWith(this.prefix)).count();
    }

    /// Iterates over this object, passing each entry to the `dg`
    public int opApply (scope MapIterator dg) scope {
        foreach (kv; this.values.byKeyValue()) {
            if (!kv.key.startsWith(this.prefix)) continue;
            const kname = this.getKeyNames(kv.key);
            scope kn = new SimpleScalar(kname[0].toLower(), Location.init);
            // If kname[1] is not empty, then it is still a mapping.
            // This still needs to be here to allow for scope allocation
            int res;
            if (kname[1].length) {
                const offset = this.prefix.length + kname[0].length + 1;
                res = this.withNewMapping(this.getPrefix(kv.key, offset),
                    (scope KeyValueMapping vn) => dg(kn, vn),
                );
            } else {
                scope vn = new SequenceOrScalar(kv.value, Location(kv.key));
                res = dg(kn, vn);
            }
            if (res) return res;
        }
        return 0;
    }

    /// Here so we can get a scope instance of the right type
    private int withNewMapping (this KVM) (string prefix,
        scope int delegate(scope KeyValueMapping nmap) dg) scope {
        // Cast to string qualifier as we always want a mutable instance
        alias MutableKVM = typeof(cast()KVM.init);
        scope nmap = new MutableKVM(prefix, this.values, this.separator);
        return dg(nmap);
    }

    /// Here to get a long-lived instance of the right type
    private KVM newMapping (this KVM) (string prefix) scope {
        return new KVM(prefix, this.values, this.separator);
    }

    public override Location location () const scope @safe nothrow {
        return Location(this.prefix.length ? this.prefix[0 .. $ - 1] : null);
    }
    public override Type type () const scope @safe nothrow { return Type.Mapping; }
    public override inout(KeyValueMapping) asMapping () inout scope @safe { return this; }
    public override inout(Sequence) asSequence () inout scope @safe { return null; }
    public override inout(Scalar) asScalar () inout scope @safe { return null; }

    /***************************************************************************

        Utility function to get the name of a 'key' in a mapping

        Returns:
          An array of two element, the current key value and the next key value.

    ***************************************************************************/

    protected string[2] getKeyNames (string value) const scope @safe {
        assert(value.length >= this.prefix.length);
        auto rng = value[this.prefix.length .. $].splitter(this.separator);
        if (rng.empty)
            return [null, null];
        const current = rng.front;
        rng.popFront();
        return [current, !rng.empty ? rng.front : null];
    }

    unittest {
        string[][string] empty;
        scope env = new KeyValueMapping("CONFIGY_", empty, '_');
        assert(env.getKeyNames("CONFIGY_HOME_USER")      == ["HOME", "USER"]);
        env.prefix = "CONFIGY_HOME_";
        assert(env.getKeyNames("CONFIGY_HOME_USER") == ["USER", null]);

        env.separator = '.';
        env.prefix = null;
        assert(env.getKeyNames("home.user") == ["home", "user"]);
        env.prefix = "home.";
        assert(env.getKeyNames("home.user") == ["user", null]);
    }

    /// Returns: A new prefix to use, without allocating
    protected string getPrefix (string variable, size_t offset)
        const scope @safe pure nothrow @nogc {
        assert(offset < variable.length);
        return variable[0 .. offset + (variable[offset] == this.separator)];
    }
}

///
public class SequenceOrScalar : Sequence, Scalar {
    /// The actual data
    private const string[] values;
    /// Location of the variable
    private Location loc;

    ///
    public this (const string[] values, Location loc) @safe pure nothrow @nogc {
        this.values = values;
        this.loc = loc;
    }

    ///
    public override int opApply(scope SeqIterator dg) scope {
        foreach (idx, value; this.values) {
            scope val = new SimpleScalar(value, this.loc);
            if (auto res = dg(idx, val))
                return res;
        }
        return 0;
    }

    ///
    public override string str () const return scope @safe {
        return this.values.length ? this.values[$-1] : null;
    }

    ///
    public override size_t length () const scope @safe { return this.values.length; }

    ///
    public override Location location () const scope @safe nothrow { return this.loc; }
    ///
    public override Type type () const scope @safe nothrow { return Type.Sequence; }
    ///
    public override inout(Mapping) asMapping () inout scope @safe { return null; }
    ///
    public override inout(SequenceOrScalar) asSequence () inout scope @safe { return this; }
    ///
    public override inout(SequenceOrScalar) asScalar () inout scope @safe { return this; }
}
