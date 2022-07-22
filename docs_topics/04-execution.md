## 4. Execution

Once compiled, a ruleset is essentially a sequence of functions to call on the
execution context.  The simplest execution context is an empty table.  If Lace
is going to store anything it will use a `_lace` prefix as with @{03-compilation.md|compilation}
contexts.  As with compilation, the caller is not permitted to put anything
inside `_lace` nor to rely on its layout.

A few important functions make up the execution engine.  The top level
function is simply:

    result, msg = lace.engine.run(ruleset, exec_context)

This will run `ruleset` with the given execution context and return
a simple result.

If `result` is `nil`, then `msg` is a long-form string error explaining
what went wrong.  It represents a Lua error being caught and as such
you may not want to report it to your users.

If `result` is `false`, then `msg` is a long-form string error
explaining that something returned an error during execution which it
would be reasonable to report to users under most circumstances.

If `result` is `"allow"`, then `msg` is an optional string saying why
the ruleset resulted in an allow.  Ditto for `"deny"`.  Essentially any
string might be a reason.  This is covered below in Commands.

Commands
========

When a command is being run, it is called as:

    result, msg = command_fn(exec_context, unpack(args))

where `args` are the arguments returned during the compilation of the command.

If the function throws an error, that will be caught and processed by
the execution engine.

If `result` is falsehood (`nil`, `false`) then the command is considered to
have failed for some reason and `msg` contains an "internal" error
message to report to the user.  This aborts the execution of the
ruleset.

If `result` is `true`, then the command successfully ran, and execution
continues at the next rule.

If `result` is a string, then the command returned a result.  This
ceases execution of the ruleset and the result and message (which must
be a string explanation) are returned to the caller.  Typically such
results would be "allow" or "deny" although there's nothing forcing
that to be the case.

Control Types
=============

When a control type function is being run, it is called as:

    result, msg = ct_fn(exec_context, unpack(args))

where `args` are the arguments returned when the definition was compiled.

If the function throws an error, it will be caught and processed by
the execution engine.

If `result` is `nil` then msg is an "internal" error, execution will be
stopped and the issue reported to the caller.

If `result` is `false`, the control call failed and returned falsehood.
Anything else and the control call succeeded and returns truth.

Control type functions are called at the point of test, not at the
point of definition.  Control type results are *NOT* cached.  It is up
to the called functions to perform any caching/memoising of results as
needed to ensure suitably performant behaviour.

Helper functions
================

Since sometimes when writing command functions, you need to know if a given
define rule passes, Lace provides a function to do this.  It is bound up in the
behaviour of Lace's internal `define` command and as such, you should treat it
as a black box.

    result, msg = lace.engine.test(exec_context, name)

This, via the magic of the execution context calls through to the
appropriate control type functions, returning their results directly.

This means that it can throw an error in the case of a Lua error,
otherwise it returns the two values as detailed above.

