/*******************************************************************************

    Contains tests related to MultiBackend (e.g. different combination)

    Copyright:
        Copyright (c) 2019-2025 Mathias Lang
        All rights reserved.

    License:
        MIT License. See LICENSE for details.

*******************************************************************************/

module configy.test.multi;

import configy.attributes;
import configy.exceptions;
import configy.read;
import configy.utils;
import configy.backend.environment;
import configy.backend.multi;
import configy.backend.node;
import configy.backend.yaml;

import std.format;

/// Test MultiBackend internals (no call to parseConfig)
unittest {
    auto n1 = parseString(`l1:
  l2:
    name: "John"
j1:
  j2:
    name: "Henry"
    age: 42
`, `/etc/node1`).asMapping();
    assert(n1 !is null);

    auto n2 = parseString(`l1:
  l2:
    name: "Fred"
    age: 24
j1:
  j2:
    age: 28
`, `/etc/node2`).asMapping();
    assert(n2 !is null);

    auto n3 = parseString(`l1:
  l2:
    name: "Brian"
`, `/etc/node3`).asMapping();
    assert(n3 !is null);

    scope root = MultiBackend.make([n3, n2, n1]);
    size_t tlCount;
    foreach (scope key, scope value; root) {
        ++tlCount;
        const k = key.asScalar().str;
        assert(k == "l1" || k == "j1");
    }
    assert(tlCount == 2,
        "We iterated more than twice at the top level");
}

/// Simple MultiBackend test with two incomplete nodes
unittest {
    static struct ClientConfig {
        bool enabled = true;
        int[] peers;
    }

    static struct ServerConfig {
        bool enabled = true;
        string greeting;
    }

    static struct Config {
        ClientConfig client;
        ServerConfig server;
    }

    auto n1 = parseString(`client:
  enabled: true
  peers:
    - 42
    - 84
server:
  enabled: false`, `/etc/node1`).asMapping();
    assert(n1 !is null);

    auto n2 = parseString(`client:
  enabled: false
server:
    enabled: true
    greeting: "Hello World"`, `/etc/node2`).asMapping();
    assert(n2 !is null);

    // n1 takes precedence
    {
        scope root = MultiBackend.make([n1, n2]);
        const result = parseConfig!Config(root);
        assert(result.client.enabled);
        assert(result.client.peers == [42, 84]);
        assert(!result.server.enabled);
        assert(!result.server.greeting.length);
    }

    // n2 takes precedence
    {
        scope root = MultiBackend.make([n2, n1]);
        const result = parseConfig!Config(root);
        assert(!result.client.enabled);
        assert(!result.client.peers.length);
        assert(result.server.enabled);
        assert(result.server.greeting == "Hello World");
    }
}

/// Test partially specified nested node across three backends
unittest {
    static struct LevelTwo {
        string name;
        int age;
    }
    static struct LevelOne {
        LevelTwo l2;
        LevelTwo j2;
    }
    static struct Config {
        LevelOne l1;
        LevelOne j1;
        LevelOne o1 = LevelOne(LevelTwo("Default", 11), LevelTwo("D2", 22));
    }

    auto n1 = parseString(`l1:
  l2:
    name: "John"
  j2:
    age: 111
j1:
  l2:
    name: "Bruce"
  j2:
    name: "Henry"
    age: 42
`, `/etc/node1`).asMapping();
    assert(n1 !is null);

    auto n2 = parseString(`l1:
  l2:
    name: "Fred"
    age: 24
  j2:
    name: "Chabal"
j1:
  l2:
    age: 666
  j2:
    age: 28
`, `/etc/node2`).asMapping();
    assert(n2 !is null);

    auto n3 = parseString(`l1:
  l2:
    name: "Brian"
`, `/etc/node3`).asMapping();
    assert(n3 !is null);

    scope root = MultiBackend.make([n3, n2, n1]);
    const result = parseConfig!Config(root);

    assert(result.l1.l2.name == "Brian");
    assert(result.l1.l2.age == 24);
    assert(result.j1.j2.name == "Henry");
    assert(result.j1.j2.age == 28);
}

/// Test EnvironmentBackend combined with YAMLBackend
unittest {
    static struct ClientConfig {
        bool enabled = true;
        int value;
    }

    static struct ServerConfig {
        bool enabled = true;
        string greeting;
    }

    static struct Config {
        ClientConfig client;
        ServerConfig server;
        ServerConfig backup;
    }

    scope n1 = EnvironmentBackend.make(`CONFIGY`, [
        `CLIENT`: `ignored`,
        `CONFIGY_SERVER_ENABLED`: `false`,
        `SERVER`: `Also ignored`,
        `CONFIGY_CLIENT_VALUE`: `42`,
        `CONFIGY_BACKUP_ENABLED`: `false`,
        `XDF_HOME_DIRECTORY`: `/home/root/`,
    ]);
    scope Mapping n2 = parseString(`backup:
  enabled: true
  greeting: "Out of Memory"`, `/etc/node1`)
        .asMapping();
    assert(n2 !is null);
    {
        scope root = MultiBackend.make([n1, n2]);
        const result = parseConfig!Config(root);
        assert(result.client.enabled);
        assert(result.client.value == 42);
        assert(!result.server.enabled);
        assert(!result.server.greeting.length);
        assert(!result.backup.enabled);
        assert(!result.backup.greeting.length);
    }

    {
        scope root = MultiBackend.make([n2, n1]);
        const result = parseConfig!Config(root);
        assert(result.client.enabled);
        assert(result.client.value == 42);
        assert(!result.server.enabled);
        assert(!result.server.greeting.length);
        assert(result.backup.enabled);
        assert(result.backup.greeting == `Out of Memory`);

    }
}

/// Behavior of enabled: The value provided always override
/// the default.
unittest {
    static struct PeerConfig {
        bool enabled = true;
        string name;
    }

    static struct Config {
        PeerConfig peer;
    }

    auto n1 = parseString(`peer:
  enabled: false`, `/etc/node1`).asMapping();
    assert(n1 !is null);

    auto n2 = parseString(`peer:
  name: "This will be ignored"`, `/etc/node2`).asMapping();
    assert(n2 !is null);

    // n1 takes precedence
    {
        scope root = MultiBackend.make([n1, n2]);
        const result = parseConfig!Config(root);
        assert(!result.peer.enabled);
        assert(!result.peer.name.length);
    }

    // n2 takes precedence but doesn't set `enabled`
    {
        scope root = MultiBackend.make([n2, n1]);
        const result = parseConfig!Config(root);
        assert(!result.peer.enabled);
        assert(!result.peer.name.length);
    }
}
