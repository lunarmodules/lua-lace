## 3. Compilation

When you construct a Lace engine, you give it a compilation callback
set.  That set is used to call you back when Lace encounters something it
needs help compiling.  The structure of it is:

    { _lace = {
       loader = function(compcontext, nametoload) ... end,
       commands = {
          ... = function(compcontext, words...) ... end,
       },
       controltype = {
          ... = function(compcontext, type, words...) ... end,
       }
    } }

Anything outside of the `_lace` entry in the context is considered
fair game structure-wise and can be used by the functions called back
to acquire internal pointers etc.  Note however that the compilation
context will not be passed around during execution so if you need to
remember some of it in order to function properly, then it's up to
you.  Also note that anything not defined above in the `_lace` example
is considered "private" to Lace and should not be touched by non-Lace
code.

In addition, Lace will maintain a `source` entry in the _lace table
with the lexed source which is being compiled and, if we're compiling
an included source, a parent entry with the compilation context of the
parent.  The toplevel field is the compilation context of the top
level compilation.  If parent is nil, then toplevel will equal
compcontext.  Lace also maintains a `linenr` entry with the
currently-being-compiled line number, so that commands and control
types can use that in error reports if necessary.

If `loader` is absent then the `include` statement refuses to include
anything mandatory.  If it is present but returns nil when called then
the `include` statement fails any mandatory includes which do so.

Otherwise the loader is expected to return the 'real' name of the
source and the content of it.  This allows for symbolic lookups.

If Lace encounters a command it does not recognise then it will call
`context._lace.commands[cmdname]` passing in the words representing the line
in question.  It's up to that function to compile the line or else to
return an error.

If Lace encounters a control type during a `define` command which it
does not understand, then it calls the `context._lace.controltype[name]`
function passing in all the remaining arguments.  The control type
function is expected to return a compiled set for the define or else
an error.

To start a Lace engine compiling a ruleset, simply do (pseudocode):

    rules, err = lace.compiler.compile(compcontext, sourcename[, sourcecontent])

If `sourcecontent` is not given, Lace will use the loader in the
`compcontext` to load the source.

If `rules` is `nil`, then `err` is a Lua error.
If `rules` is `false`, then `err` is a formatted error from compilation
Otherwise, `rules` should be a table containing the ruleset.

Internally, once compiled, Lace rulesets are a table of tables.  Each
rule entry has a reference to its source and line number.  It then has
a function pointer for executing this rule, and a set of arguments to
give the rule.  Lace automatically passes the execution context as the
first argument to the rule.  Sub-included rulesets are simply one of
the arguments to the function used to run the rule.

Loader
======

When Lace wishes to load an entry, it calls the `loader` function.  This
is to allow rulesets to be loadable from arbitrary locations such as
files on disk, HTTP URLs, random bits of memory or even out of version
control repositories directly.

The `loader` function is given the compilation context and the name of the
source to load.  Note that while it has the compilation context, the loader
function must be sensitive to the case of the initial load.  Under that
circumstance, the source information in the compilation context will be
unavailable.  The loader function is required to fit the following pseudocode
definition:

    realname, content = loader(compcontext, nametoload)

If `realname` is not a string then content is expected to be an
"internal" error message (see below) which will be augmented with the
calling source position etc and rendered into an error to return to
the caller of `lace.compiler.compile()`.

If `realname` is a string then it is taken to be the real name of the
loaded content (at worst you should return nametoload here) and
`content` is a string representing the contents of that file.

Once it has been loaded by the `loader` function, Lace will compile that
sub-ruleset before continuing with the current ruleset.

Commands
========

When Lace wishes to compile a command for which it has no internal
definition, it will call the command function provided in the
compilation context.  If no such command function is found, it will
produce an error and stop the compilation.

The command functions must fit the following pseudocode definition:

    cmdtab, msg = command_func(compcontext, words...)

If `cmdtab` is not a table, msg should be an "internal" error message
(see below) which will be augmented with the calling source position
etc and rendered into an error to return to the caller of
`lace.compiler.compile()`.

If `cmdtab` is a table, it is taken to be the compiled table
representing the command to run at ruleset execution time.  It should
have the form:

    { fn = exec_function, args = {...} }

Lace will automatically augment that with the source information which
led to the compiled rule for use later.

The `exec_function` is expected to fit the following pseudocode
definition:

    result, msg = exec_function(exec_context, unpack(args))

See @{04-execution.md|execution} for notes on how these `exec_function`
functions are meant to behave.

Control Types
=============

When Lace is compiling a definition rule with a control type it has
not got internally, Lace will call the controltype function associated
with it (or report an error if no such control type is found).

The control type functions must fit the following pseudocode
definition:

    ctrltab, msg = controltype_func(compcontext, type, words...)

If `ctrltab` is not a table, msg should be an "internal" error message
(see below) which will be augmented with the calling source position
etc and rendered into an error to return to the caller of
`lace.compiler.compile()`.

If `ctrltab` is a table, it is taken to be the compiled table
representing the control type to run at ruleset execution time.  It
should have the form:

    { fn = ct_function, args = {...} }

The `ct_function` is expected to fit the following pseudocode
definition:

    result, msg = ct_function(exec_context, unpack(args))

See @{04-execution.md|execution} for notes on how these `ct_function` functions
are meant to behave.

Compiler internal errors
========================

Error messages during compilation are generated by calling:

    return lace.error.error("my message", { x, y })

Where the table is a list of numeric indices of the words which caused the
error.  If words is empty (or nil) then the error is considered to be the
entire line.

Lace will use this information to construct meaningful long error
messages which point at the words in question.  Such as:

    Unknown command name: 'go_fish'
    myruleset :: 6
    go_fish "I have no bananas"
    ^^^^^^^

In the case of control type compilation, the words will automatically be offset
by the appropriate number to account for the define words.  This means you
should always 1-index from your arguments where index 1 is the control type
word index.

The same kind of situation occurs during @{04-execution.md|execution}.
