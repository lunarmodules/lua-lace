## 2. Syntax


Lace rule files are parsed line-by-line.  There is no provision at
this time for rules to be split across multiple lines.  If you require
such, please @{05-developing.md|submit a patch}.

Lace splits each line into a series of tokens.  Tokens are always
strings and they can be optionally quoted to allow for spaces in them.
Certain tokens then have constraints placed on them so that further
parsing will be unambiguous.

The lexing into tokens is done similarly to how shell does it.  This
means that each whitespace-separated "word" is then subjected to
quoting rules.  Lace does not have many special characters.  The
backslash introduces escaped values in all cases and lace does not
differentiate between single and double quotes.  Backslash escaped
characters sometimes have special meaning if inside quotes.  For
example, the following strings lex in the following ways:

1. Two tokens, one of each word.

          hello world

2. The same as 1.

          hello   world

3. One token with both words separated by one space

          "hello world"

4. Same as 3.

          'hello world'

5. Same as 3 and 4.

          hello\ world

6. One token, consisting of the letters: `uptown`

          up\town

6. One token, consisting of the letters: `up TAB own`

          "up\town"

7. One token, a double-quote character

          \"

8. The same as 7

          '"'

9. The same as 7 and 8.

          "\""


As you can see, the lexing rules are not trivial, but should not come
as a surprise to anyone used to standard command-line lexing
techniques.

Comments in Lace are prefixed by a hash '#', a double-slash '//' or a
double-dash '--'.  The first word of the line must start with one of
these markers (but may contain other text also), for example:

    # This is a comment
    // As is this
    -- And this

    #But also this
    //And this
    --And also this

Blank lines are permitted and ignored (except for counting), any
prefixed or postfixed whitespace is deleted before lexing begins.  As
such:

    # This is a comment
      # So is this

This allows for sub-rulesets to be indented as the author pleases,
without altering the meaning of the rules.

The first word of a rule defines its type.  You can think of it as the
command being run.  Lace, by default, provides a small number of rule
types:

1. @{02.1-syntax-define.md|Definitions}:
This define access control stanzas.  The definitions produced are
used in further rules to control access.  Lace does not allow any
name to be reused.

2. @{02.2-syntax-include.md|Includes}:
Lace can include further rules at any point during a ruleset.  If
the rules are to be optionally run then Lace cannot perform static
analysis of the definitions within the ruleset.  Instead it will
rely on runtime catching of multiple-definitions etc.

3. @{02.3-syntax-allow-deny.md|Access control statements}:
These are the core functions of Lace.  Namely the allow and deny
statements.  These use control definitions from earlier in a ruleset
to determine whether to allow or deny access.  The first allow
or deny statement which passes will stop execution of the ruleset.

4. @{02.4-syntax-default.md|Default statement}:
The 'default' statement can only be run once and provides Lace with
information on what to do in the case of no allow or deny rule passing.

In those files, if you encounter the words WILL, MAY, SHOULD, MUST, or
their negatives, specifically in all-caps, then the meaning of the
words is taken in the spirit of the RFC usage of them.
