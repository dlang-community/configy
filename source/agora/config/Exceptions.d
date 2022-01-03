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

        This format the error in a nicer format (with colors if possible),
        and will additionally provide a stack-trace if the `ConfigFillerDebug`
        `debug` version was provided.

        Params:
          sink = The sink to send the piece-meal string to

    ***************************************************************************/

    public override void toString (scope void delegate(in char[]) sink) const scope
    {
        import core.internal.string : unsignedToTempString;

        char[20] buffer = void;

        sink(Yellow);
        sink(this.yamlPosition.name);
        sink(Reset);

        sink("(");
        sink(Cyan);
        sink(unsignedToTempString(this.yamlPosition.line, buffer));
        sink(Reset);
        sink(":");
        sink(Cyan);
        sink(unsignedToTempString(this.yamlPosition.column, buffer));
        sink(Reset);
        sink("): ");

        sink(this.msg);

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
}
