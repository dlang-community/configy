# Configy rationale

The following explains the rationale versus various decisions made in Configy.

## Use cases

Configy was originally designed with an application-first mindset: a developer should
design their config file based on a `struct` definition they chose, and would potentially
have a slightly different configuration file depending on the problem domain (for example,
the `@Key("name")` attribute).

While this is still the primary use-case for Configy, it is also very convenient to
read and validate a schema that is outside of the application's control,
such as `dub.json`, `.gitlab-ci.yml` / GitHub actions file, or a replacement for
a JSON schema.

As Configy supports an opiniated subset of all possible YAML schemas, there might be cases
where the schema does not fit within that subset, whether because the use case wasn't
presented before (in which case Configy could be changed to handle it) or if the approach
is uncommon practice or not intended to be supported. One example of this is section names:
one could support arbitrary section names with an associative array, but it would be better
done with `@Key("nameField")`.

For such cases that fall outside of Configy's expectations, one may always "drop down"
to using hooks (such as `fromString` or `fromConfig`) to implement any custom logic.

## Data vs Identity

Configy being a DLang library adheres to one of the core tenet of the language,
which is to have a clear separation between data (stored in `struct`) and objects
with an identity (stored in `class`es). As configuration is data, Configy explicitly
does not support classes.

## The `struct` as the source of truth

When designing with internal schema in mind, there should be a top-level `struct`
that completely defines the program's configuration. Almost all of Configy's logic
will be driven by this `struct`. It is not possible to have fields that are ignored
by Configy - configuration shouldn't be mixed with non-configuration. Likewise,
methods that are not hooks or simple getters are discouraged - treat it like a pure
piece of data, and any custom / advanced logic should be built on top.

As much of the configuration properties as possible should be derived from
that `struct`. The main example of this design is the handling of default values:
if there is an initializer, it means there is a *sane* default value provided
by the developer, hence it needs not be a required field in the configuration.

Another opiniated design decision is that all fields are known, and required by default.
All fields being known means that, by default, Configy will error out if the document
contains fields that are not present in the `struct`. While there are various legitimate
use cases for unknown fields (such as forward-compatible configuration parsing and
variable field names), being strict by default avoids the common pitfall of user typo,
which is a problem for every configuration file.

## External types

When designing a config format, even for internal schema, it might be useful to
have types that are external, such as library types (be it Phobos, Vibe.d, or another).
Those types are unlikely to have `fromConfig` support, and hence might need to be wrapped
in another project-controlled type to be present in the configuration struct. To avoid
needless wrapping, Configy supports the most common construction protocols: field-wise
constructor (the default constructor), string constructor, or `fromString`. Anything
else is likely to require a wrapping type that uses one of those methods, or `fromConfig`.

## Escape hatch

In order to support both external schema, and unforeseen internal schema use cases,
Configy provides a powerful escape hatch in the form of the `static` `fromConfig`
method. In order to avoid losing all the convenience of Configy once one "drops down"
to that level, the `ConfigParser` exposes a `parseAs` method which allows one to
recurse into the regular Configy parsing.

## Not fit for API or general purpose

The goal of Configy is to parse **configuration files**. For most applications, this
happens once per program run. For some, it may happens a few rare times (such as when
the service is reloaded). As a result, and for the sake of simplicity, Configy does not
allow to configure the memory allocator, and while speed is important, functionality
trumps performance. Thus, it is discouraged to use Configy for interacting with an API
or doing frequent, business critical work.

## Separating reading from attributes

In order to avoid bloated compile times, most of the compile-time magic is kept in
`configy.read`, and the module `configy.attributes` is kept (almost) clear of complex
logic. This is because the module containing the configuration format is likely to be
imported in many places accross the codebase, but reading can be abstracted behind
a function that is only compiled once (even with separate compilation), ensuring
that the CTFE does not have too much of an impact on a project's compilation speed.
