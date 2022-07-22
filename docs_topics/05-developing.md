## Helping with Development


The Lace codebase is divided up in to directories:

    lace/
         lib/
             ... The Lace libraries live here
         test/
             ... All the tests and their data live here
         example/
             ... The example and its data lives here
         extras/
             ... The Lua coverage tool lives here
         doc/
             ... All the documentation lives here

The codebase has a top level `Makefile` which defaults to running the test
suite.  The test suite requires Lua be present and as well as running all the
tests, also runs the Lua coverage tool to produce `luacov.report.out` which
details the coverage of the Lace codebase.

It is a policy that releases must have 100% coverage from the test suite.
Ideally 100% coverage would be attained by the test cases for the given modules
but sometimes cross-module usage is required in order to best provide 100%
coverage.

Any line not covered by the tests will be marked the `***0` in the
`luacov.report.out` file.

If you make substantive non-backward-compatible changes to the API of Lace then
you should increment the ABI number in the main `lib/lace.lua` file.  If you
make bug fixes or backward-compatible improvements then don't worry, the
version number in that file will be incremented during the release process.

If you add more modules to Lace, you should note that you need to update:

1. The `Makefile`'s `MODULES` variable
2. The `test/` directory will need a `test-lace.NEWMODULE.lua` file
3. You will need to alter `lib/lace.lua` to pull it in and update
   the `test/test-lace.lua` test to include a check for the new module
4. You should ensure your new tests in 2 cover the module fully.
5. You should ensure that any changes are shown in the example if possible.
6. You should ensure any changes are reflected in the `docs/` files.

You can check individual test suite coverage by running:

    make MODULES=lace.SOMEMODULE

This will cause the test suite for the named modules *only* to be run, and for
the coverage data for that module to be generated.  It is not policy that a
given module's individual tests MUST cover the module 100%, but if possible it
SHOULD.  It is, as stated before, policy that the full test suite should cover
100% of the modules when run as a whole though.

