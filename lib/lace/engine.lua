-- lib/lace/engine.lua
--
-- Lua Access Control Engine -- Ruleset runtime engine
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For licence terms, see COPYING
--

--- The runtime engine for the Lua Access Control Engine
--
-- Once a ruleset has been compiled, it can be run for multiple inputs without
-- needing to be recompiled.  This is handy for controlling access to a
-- long-lived daemon such as an HTTP proxy.

local err = require 'lace.error'

local unpack = unpack or table.unpack

local function _dlace(ctx)
   local ret = ctx._lace or {}
   ctx._lace = ret
   return ret
end


--- Set a definition.
--
-- @tparam table exec_context The execution context for the runtime.
-- @tparam string name The name of the define to set.
-- @tparam table defn The definition function to use.
-- @treturn boolean Returns true if the definition was set successfully.
-- @treturn nil|table If the definition was not set successfully then this is
--                    the error table ready to have context added to it.
-- @function define
local function set_define(exec_context, name, defn)
   local dlace = _dlace(exec_context)
   dlace.defs = dlace.defs or {}
   if dlace.defs[name] then
      return err.error("Attempted to redefine " .. name, {2})
   end
   dlace.defs[name] = defn
   return true
end

--- Test a definition.
--
-- @tparam table exec_context The execution context for the runtime.
-- @tparam string name The name of the define to test.
-- @treturn boolean|nil If the named definition does not exist, this is nil.
--                      Otherwise it is true iff. the definition's function
--                      results in true.
-- @treturn nil|table If the named definition does not exist, this is the error
--                    table ready for filling out with more context.
--                    Otherwise it is nil.
-- @function test
local function test_define(exec_context, name)
   local dlace = _dlace(exec_context)
   dlace.defs = dlace.defs or {}
   local defn = dlace.defs[name]
   if not defn then
      return err.error("Unknown definition: " .. name, {1}, true)
   end
   -- Otherwise we evaluate the definition and return it
   return defn.fn(exec_context, unpack(defn.args))
end

--- Internal routine for running sub-rulesets
--
-- @tparam table ruleset The compiled ruleset to run.
-- @tparam table exec_context The execution context for the runtime.
-- @treturn nil|boolean|string The first return value is `nil` in the case
--                             of a runtime error, `false` if a Lace error
--                             was encountered during runtime, otherwise it it
--                             a result string (typically `allow` or `deny`).
--                             In addition, internally, an empty result string
--                             will be returned if no result was set by the
--                             sub-ruleset.
-- @treturn nil|string If an error was encountered, this is the error message,
--                     otherwise it is an additional message to go with the
--                     result if there was one, or `nil` in the case of no
--                     result value being set by the ruleset.
-- @function internal_run
local function internal_run_ruleset(ruleset, exec_context)
   -- We iterate the ruleset, returning the first time
   -- a rule either errors, or returns a stopping result
   local dlace = _dlace(exec_context)
   dlace.ruleset = ruleset
   for i = 1, #ruleset.rules do
      local rule = ruleset.rules[i]
      dlace.linenr = rule.linenr
      local result, msg = rule.fn(exec_context, unpack(rule.args))
      if not result then
	 return false, err.augment(msg, rule.source, rule.linenr)
      elseif result ~= true then
	 -- Explicit result, return it
	 return result, msg
      end
   end
   dlace.linenr = nil

   -- Internally we use the empty string to indicate no result.
   return ""
end

--- Run a ruleset.
--
-- @tparam table ruleset The compiled ruleset to run.
-- @tparam table exec_context The execution context for the runtime.
-- @treturn nil|boolean|string The first return value is `nil` in the case
--                             of a runtime error, `false` if a Lace error
--                             was encountered during runtime, otherwise it it
--                             a result string (typically `allow` or `deny`).
-- @treturn string If an error was encountered, this is the error message,
--                 otherwise it is an additional message to go with the result.
-- @function run
local function run_ruleset(ruleset, exec_context)
   local ok, ret, msg = xpcall(function()
				  return internal_run_ruleset(ruleset, exec_context)
			       end, debug.traceback)
   if not ok then
     --luacheck: ignore 421/msg
      local _, msg = err.error(ret, {1})
      return nil, err.render(err.augment(msg, ruleset.rules[1].source, ruleset.rules[1].linenr))
   end

   assert(ret ~= "", "It should not be possible for a ruleset to fail to return a result")

   if type(msg) == "table" then
      msg = err.render(msg)
   end

   return ret, msg
end

return {
   internal_run = internal_run_ruleset,
   run = run_ruleset,
   test = test_define,
   define = set_define,
}
