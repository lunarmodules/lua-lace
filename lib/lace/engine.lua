-- lib/lace/engine.lua
--
-- Lua Access Control Engine -- Ruleset runtime engine
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For licence terms, see COPYING
--

local function _error(str, words)
   return { msg = str, words = words }
end

local function _dlace(ctx)
   local ret = ctx[".lace"] or {}
   ctx[".lace"] = ret
   return ret
end

local function set_define(exec_context, name, defn)
   local dlace = _dlace(exec_context)
   dlace.defs = dlace.defs or {}
   if dlace.defs[name] then
      return false, _error("Attempted to redefine " .. name, {2})
   end
   dlace.defs[name] = defn
   return true
end

local function test_define(exec_context, name)
   local dlace = _dlace(exec_context)
   dlace.defs = dlace.defs or {}
   local defn = dlace.defs[name]
   if not defn then
      return nil, _error("Unknown definition: " .. name)
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
	 return false, msg
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
      return nil, ret
   end

   if ret == "" then
      -- Empty string indicates no error but no result, we don't like
      -- that here so we return an error
      return false, "Ruleset did not explicitly allow or deny"
   end

   return ret, msg
end

return {
   run = run_ruleset,
   test = test_define,
   define = set_define,
}
