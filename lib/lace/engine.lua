-- lib/lace/engine.lua
--
-- Lua Access Control Engine -- Ruleset runtime engine
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For licence terms, see COPYING
--

local err = require 'lace.error'

local function _dlace(ctx)
   local ret = ctx._lace or {}
   ctx._lace = ret
   return ret
end

local function set_define(exec_context, name, defn)
   local dlace = _dlace(exec_context)
   dlace.defs = dlace.defs or {}
   if dlace.defs[name] then
      return err.error("Attempted to redefine " .. name, {2})
   end
   dlace.defs[name] = defn
   return true
end

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

local function run_ruleset(ruleset, exec_context)
   local ok, ret, msg = xpcall(function() 
				  return internal_run_ruleset(ruleset, exec_context)
			       end, debug.traceback)
   if not ok then
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
