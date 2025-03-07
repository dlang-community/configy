/*******************************************************************************

    Contains tests related to MultiBackend (e.g. different combination)

    Copyright:
        Copyright (c) 2019-2025 Mathias Lang
        All rights reserved.

    License:
        MIT License. See LICENSE for details.

*******************************************************************************/

module configy.test.environment;

import configy.attributes;
import configy.exceptions;
import configy.read;
import configy.utils;
import configy.backend.environment;
import configy.backend.node;

import std.format;

/// Test EnvironmentBackend
unittest {
    static struct ClientConfig {
        string host;
        ushort port;
    }

    static struct Config {
        ClientConfig local;
        ClientConfig production;
    }

    scope n1 = EnvironmentBackend.make(`CONFIGY`, [
        `CLIENT`: `ignored`,
        `CONFIGY_LOCAL_HOST`: `http://localhost/`,
        `CONFIGY_LOCAL_PORT`: `587`,
        `CONFIGY_PRODUCTION_HOST`: `http://remote/`,
        `CONFIGY_PRODUCTION_PORT`: `666`,
        `SERVER`: `Also ignored`,
    ]);

    const result = parseConfig!Config(n1);
    assert(result.local.host == `http://localhost/`);
    assert(result.local.port == 587);
    assert(result.production.host == `http://remote/`);
    assert(result.production.port == 666);
}
