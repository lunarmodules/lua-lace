-- lace/example/lace-example.lua
--
-- Lua Access Control Engine -- Example usage
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For licence terms, see COPYING
--

-- This is an example of how to implement Lace as your access
-- control engine.  We demonstrate all the steps necessary to
-- construct a compilation context, compile a ruleset and
-- execute it with various execution contexts.
--
-- Normally this would be spread across your program with the
-- ruleset compilation done during the evaluation of config
-- files and the execution done at the point of access control.
--
-- However, for the sake of simplicity, everything is done here
-- in one file, split into sections
--

--[ Application configuration ]--------------------------------------

local base_dir = (os.getenv("EXAMPLE_DIR") or "example")

--[ Utility functions used during execution ]------------------------

local function deep_copy(t, memo)
   if not memo then memo = {} end
   if memo[t] then return memo[t] end
   local ret = {}
   local kk, vv
   for k, v in pairs(t) do
      kk, vv = k, v
      if type(k) == "table" then
	 kk = deep_copy(k)
      end
      if type(v) == "table" then
	 vv = deep_copy(v)
      end
      ret[kk] = vv
   end
   return ret
end

--[ Preparing the compilation context ]------------------------------

local lace = require 'lace'

-- Loader
--
-- This function is used by Lace to load rulesets into memory.  Note
-- that it is not required to parse anything and may return errors if
-- it so requires.  It may also throw Lua errors, although that is
-- only suggested in the most extreme of circumstances.
--
-- Its inputs are the compilation context and the name of the rule to
-- be loaded.  This is used both for initial loads (unless the ruleset
-- is given to lace.compiler.compile() and also for include statements.
--
-- If the ruleset cannot be found, the loader is required to return a
-- lace error, not throw a Lua error.  Throwing a lua error will
-- always stop compilation.  However returning a lace error can allow
-- compilation to continue if the include is an optional one.  The
-- returned lace error should contain a reference to word 1 which is
-- the name of the ruleset to be loaded.
--
-- On successful load of content, the loader should return the "real"
-- name of the loaded ruleset (used for further errors etc) and the
-- content of the ruleset as a string.
--
local function lace_loader(comp_ctx, name)
   local fname = base_dir .. "/" .. name .. ".rules"
   local fh = io.open(fname, "r")
   if not fh then
      return lace.error.error("Unable to find ruleset", {1})
   end
   local content = fh:read("*a")
   fh:close()
   return fname, content
end

-- Control types
--
-- Control types are used by Lace to allow the ruleset to define
-- behaviours and thus they provide the primary functionality of the
-- access control system.
--
-- Lace provides two control types by default, 'anyof' and 'allof'
-- which are simple combinators which require that any of their
-- arguments are true, or all of them are true, respectively.
--
-- Anything else which takes a list of defined rules behaves with the
-- allof behaviour.  So an 'allow' with multiple rules requires that
-- they all be true in order to allow the access.
--
-- Here we define a simple equality control type used in our example
-- rulesets.  Quite simply a control type must return true or false in
-- case of the match succeeding or failing.  If instead they have an
-- error for some reason, they should return a lace error with the
-- nil-error indicator set instead.
--
local function equality_control_type_run(exec_ctx, key, value)
   if exec_ctx[key] == nil then
      return lace.error.error("Key " .. key .. " not found", {}, true)
   end

   return exec_ctx[key] == value
end
--
-- The control type compiler though should return a table with the
-- information required to run the control object at execution time.
--
-- Required information is the function to call and the arguments to
-- pass it.  Everything else will be acquired from the execution
-- context at runtime.
--
-- If the compilation of the control type fails then this function
-- should return a lace error indicating what is at fault.  If the
-- function instead raises a lua error then compilation will cease,
-- but a less useful (to the user) error will be returned to the
-- caller.
--
local function equality_control_type(comp_ctx, eq, key, value, extra)
   assert(eq == "equals", "Somehow the equals control type was called for something else")
   if key == nil then
      return lace.error.error("Expected a key for equality check", {1})
   end
   if value == nil then
      return lace.error.error("Got a key, but expected a value", {1,2})
   end
   if extra ~= nil then
      return lace.error.error("Unexpected extra content", {4})
   end
   return {
      fn = equality_control_type_run,
      args = { key, value }
   }
end

-- We now have the minimum necessary to construct a compilation
-- context which can then be used to compile our ruleset.  To do this,
-- we construct a table whose _lace entry contains our loader and our
-- control types.
--
local template_compilation_context = {
   _lace = {
      loader = lace_loader,
      controltype = {
	 equals = equality_control_type,
      },
   },
}


--[ Compiling a ruleset (during config load) ]-----------------------

-- Compiling a ruleset is as simple as calling lace.compiler.compile()
-- and handing in a compilation context and the name of the ruleset to
-- load.  In order to be safe to compile multiple rulesets, you should
-- always be sure to copy a fresh compilation context for use.
--
-- Note: rulesets are loaded completely at compile time.  If there is
-- something in your ruleset which depends on access-time behaviour
-- then you should either changing how your rulesets will work, or
-- else you must compile the ruleset at access time which could be
-- wasteful.
local comp_ctx = deep_copy(template_compilation_context)
local ruleset, msg = lace.compiler.compile(comp_ctx, "NOTFOUND")

-- When the compilation fails, the 'ruleset' return will be false and
-- the msg return will be a multiline string indicating the error.
assert(ruleset == false, "Compilation somehow succeeded unexpectedly")
print ">>> Message for a not-found compilation attempt"
print(msg)
print "<<<"

-- So let's try again with a ruleset which should exist
comp_ctx = deep_copy(template_compilation_context)
-- Since we're sure it should exist, let's assert it
ruleset = assert(lace.compiler.compile(comp_ctx, "example"))

--[ Running the ruleset (during user access) ]-----------------------

-- Running the engine
--
-- Since to run the access control engine we need an execution context
-- we will put one together.  In a real application the execution
-- context will contain information pertaining to the access being
-- tested.  For this example, it will simply contain enough data to
-- either pass or fail the example ruleset.

-- Generate an execution context
--
local function gen_exec_ctx(want_to_pass)
   return {
      want_to_pass = want_to_pass and "yes" or "no"
   }
end

-- Running the ruleset
--
-- Here's an example of running a ruleset.  To run a ruleset you call
-- lace.engine.run() passing the ruleset and the execution context.
--
-- If the ruleset errors in any way, result will be false and msg will
-- be a message to give back to the user or developer.
--
local result, msg = lace.engine.run(ruleset, {})
assert(result == false, "Ruleset should have errored")
print ">>> Error from a control type failing somehow"
print(msg)
print "<<<"

-- If the ruleset succeeds, result will be one of 'allow' or 'deny'
-- and the message will be the message to give to the user if
-- necessary and log otherwise.
result, msg = lace.engine.run(ruleset, gen_exec_ctx(true))
print("should be ok", result, msg)

-- Note that even if the ruleset denies access, that's a successful
-- running of the ruleset, so you can test for denial and act
-- appropriately.
result, msg = lace.engine.run(ruleset, gen_exec_ctx(false))
print("should fail", result, msg)

