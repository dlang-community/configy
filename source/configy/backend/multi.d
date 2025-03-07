/*******************************************************************************

    A backend that is composed of multiple backends

    This can be used for a variety of purposes: to have Configy parse the
    content of multiple files at once, with the first file having priorities
    over the values, to add overrides, such as environment variables
    or command-line arguments, or even to compose multiple formats.

*******************************************************************************/

module configy.backend.multi;

import configy.backend.node;

import std.algorithm;
import std.exception;

/// This struct simply acts as a namespace to simplify importing multiple backends
public struct MultiBackend {

    /***************************************************************************

        Get a mapping proxying multiple mappings

        A `MultiMapping` will simply wrap another set of mappings and iterate on
        their values, in the order of their parent nodes being passed to this
        function.

        Params:
          nodes = The nodes to wrap (highest priority first).

        Returns:
          The root node for the `MultiMapping`.

    ***************************************************************************/

    public static MultiMapping make (Mapping[] nodes) @safe {
        assert(nodes.length > 0, "No nodes passed to MultiBackend");
        return new MultiMapping(nodes);
    }
}


///
public class MultiMapping : Mapping {
    /// The underlying nodes
    protected Mapping[] nodes;

    ///
    public this (Mapping[] nodes) @safe pure nothrow @nogc {
        assert(nodes.length);
        this.nodes = nodes;
    }

    ///
    public override Type type () const scope @safe nothrow {
        return Type.Mapping;
    }

    ///
    public override Location location () const scope @safe nothrow {
        return this.nodes[0].location();
    }

    ///
    public override inout(Mapping)  asMapping () inout scope @safe { return this; }
    public override inout(Sequence) asSequence () inout scope @safe { return null; }
    public override inout(Scalar)   asScalar () inout scope @safe   { return null; }

    /// Returns: The length of this object (the number of entries in it)
    public size_t length () const scope @safe {
        return this.nodes[0].length();
    }

    /// Iterates over this object, passing each entry to the `dg`
    public int opApply (scope MapIterator dg) scope {
        enforce(this.nodes.length < typeof(MultiMappingBuffer.buffer).length,
            "Having more than 256 backends is not supported");

        foreach (idx, n; this.nodes) {
            foreach (scope key, scope value; n) {
                auto kv = enforce(key.asScalar(), "Key is not a value");
                // Skip over keys that have been previously visited
                if (this.nodes[0 .. idx].any!(n => n.has(kv.str)))
                    continue;

                if (auto m = value.asMapping()) {
                    // If the value is a mapping, we need to wrap it in a `MultiMapping`,
                    // otherwise mapping will not be properly merged.
                    // Since some backend might not allocate, we have to recurse to fill
                    // a static array.
                    MultiMappingBuffer buff;
                    if (int res = buff.accumulate(kv, this.nodes[idx .. $], dg))
                        return res;
                } else {
                    if (int res = dg(key, value))
                        return res;
                }
            }
        }
        return 0;
    }
}

/**
 * An utility buffer to accumulate Mapping into
 *
 * When we iterate over a mapping and encounter another mapping, we need to
 * recurse and instantiate a MultiMapping wrapper so that nodes get properly
 * merged. To make this possible without allocating or branching too much,
 * we use this struct to give us a static buffer, and skip empty (null) nodes.
 */
private struct MultiMappingBuffer {
    /// The underlying buffer
    private Mapping[256] buffer;
    /// Our position in the buffer
    private size_t idx;

    /// Adds a node to the buffer - skip any `null` node
    public void add (scope Mapping node) @safe scope return {
        if (node is null) return;
        this.buffer[this.idx++] = node;
    }

    /// Returns: A slice of the buffer with all non-null node
    public Mapping[] opSlice () @safe scope return {
        return this.buffer[0 .. this.idx];
    }

    /// Accumulate all sub-mapping of `nodes` that have key `key`,
    /// then call `resolve` with a `MultiMapping` wrapping them.
    private int accumulate (scope Scalar key, scope Mapping[] nodes, scope Mapping.MapIterator resolve) {
        if (!nodes.length) {
            scope mm = new MultiMapping(this[]);
            return resolve(key, mm);
        }
        return nodes[0].withNode(key.str(), (scope Node k, scope Node v) {
            this.add(v ? v.asMapping() : null);
            return this.accumulate(key, nodes[1 .. $], resolve);
        });
    }
}
