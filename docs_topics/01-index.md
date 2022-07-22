## 1. Lua Access Control Engine

Lace is the core of an access control engine designed to be embedded into other
applications.  It is also designed to be extended by the very applications it
is embedded into.

As such, Lace provides only the core lexing, parsing, error handling and
related functionality of an access control engine, along with some initial
semantics to help the application developer along.

All rules and mechanisms of deciding if access is to be permitted or not are up
to the application author to define.  As such, while this documentation for
Lace will be useful for the application developer; it is recommended that the
applications do not refer their users to the Lace documentation except to
augment that provided in the application specific documentation.

The Lace codebase provides an example of using the library which should be
referred to for getting started with Lace.  However, there is also extensive
documentation on the @{02-syntax.md|syntax} of Lace rulesets and also on the
@{03-compilation.md|compilation} and @{04-execution.md|execution} phases of
access control.

If you wish to assist with Lace development, then see the @{05-developing.md|developing}
document for pointers around the codebase and the test suite.

