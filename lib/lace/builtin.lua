-- lib/lace/builtin.lua
--
-- Lua Access Control Engine -- Builtin commands for Lace
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For Licence terms, see COPYING
--

local builtin = {}

local function compiler()
   return require "lace.compiler"
end

local function _do_return(exec_context, result, reason, cond)
   if #cond > 0 then
      -- Run the conditions
   end
   return result, reason
end

local function _return(compcontext, result, reason, ...)
   if result ~= "allow" and result ~= "deny" then
      return compiler().error("Unknown result: " .. result, {1})
   end
   if type(reason) ~= "string" then
      return compiler().error("Expected reason, got nothing")
   end
   return {
      fn = _do_return,
      args = {
	 result,
	 reason,
	 {...}
      }
   }
end

builtin.allow = _return
builtin.deny = _return

return {
   commands = builtin,
}
