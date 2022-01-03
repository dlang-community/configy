/*******************************************************************************

    Definitions for Exceptions used by the config module.

    Copyright:
        Copyright (c) 2019-2021 BOSAGORA Foundation
        All rights reserved.

    License:
        MIT License. See LICENSE for details.

*******************************************************************************/

module agora.config.Exceptions;

import agora.config.Utils;

import dyaml.exception;
import dyaml.node;

import std.format;

/// A convenience wrapper around `enforce` to throw a formatted exception
package void enforce (E = ConfigException, Args...) (Node node, bool cond,
                                string fmt, lazy Args args,
                                string file = __FILE__, size_t line = __LINE__)
{
    if (!cond)
        throw new E(format(fmt, args), node.startMark(), file, line);
}

/// Exception type thrown by the config parser
public class ConfigException : Exception
{
    /// Position at which the error happened
    public Mark yamlPosition;

    /// Constructor
    public this (string msg, Mark position,
                 string file = __FILE__, size_t line = __LINE__)
        @safe pure nothrow @nogc
    {
        super(msg, file, line);
        this.yamlPosition = position;
    }

    /***************************************************************************

        Overrides `Throwable.toString` sink overload

        It is quite likely that errors from this module may be printed directly
        to the end user, who might not have technical knowledge.

        This format the error in a nicer format (e.g. with colors),
        and will additionally provide a stack-trace if the `ConfigFillerDebug`
        `debug` version was provided.

        Format_chars:
          The default format char ("%s") will print a regular message.
          If an uppercase 's' is used ("%S"), colors will be used.

        Params:
          sink = The sink to send the piece-meal string to
          spec = See https://dlang.org/phobos/std_format_spec.html

    ***************************************************************************/

    public override void toString (scope void delegate(in char[]) sink) const scope
    {
        this.toString(sink, FormatSpec!char("%s"));
    }

    /// Ditto
    public void toString (
        scope void delegate(in char[]) sink, in FormatSpec!char spec) const scope
    {
        import core.internal.string : unsignedToTempString;

        const useColors = spec.spec == 'S';
        char[20] buffer = void;

        if (useColors) sink(Yellow);
        sink(this.yamlPosition.name);
        if (useColors) sink(Reset);

        sink("(");
        if (useColors) sink(Cyan);
        sink(unsignedToTempString(this.yamlPosition.line, buffer));
        if (useColors) sink(Reset);
        sink(":");
        if (useColors) sink(Cyan);
        sink(unsignedToTempString(this.yamlPosition.column, buffer));
        if (useColors) sink(Reset);
        sink("): ");

        this.formatMessage(sink, spec);

        debug (ConfigFillerDebug)
        {
            sink("\n\tError originated from: ");
            sink(this.file);
            sink("(");
            sink(unsignedToTempString(line, buffer));
            sink(")");

            if (!this.info)
                return;

            try
            {
                sink("\n----------------");
                foreach (t; info)
                {
                    sink("\n"); sink(t);
                }
            }
            // ignore more errors
            catch (Throwable) {}
        }
    }

    /// Hook called by `toString` to simplify coloring
    protected void formatMessage (
        scope void delegate(in char[]) sink, in FormatSpec!char spec) const scope
    {
        sink(this.msg);
    }
}
