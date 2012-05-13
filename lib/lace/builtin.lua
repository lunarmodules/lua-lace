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

--[ Allow and Deny ]------------------------------------------------

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

--[ Default for Allow and Deny ]------------------------------------

function builtin.default(compcontext, def, result, reason, unwanted)
   assert(def == "default", "Somehow, builtin.default got something odd")
   if type(result) ~= "string" then
      return compiler().error("Expected result, got nothing")
   end
   if result ~= "allow" and result ~= "deny" then
      return compiler().error("Result wasn't allow or deny", {2})
   end
   if type(reason) ~= "string" then
      reason = "Default behaviour"
   end
   if unwanted ~= nil then
      return compiler().error("Unexpected additional content", {4})
   end

   if compcontext[".lace"].default then
      return compiler().error("Cannot change the default")
   end

   compcontext[".lace"].default = { result, reason }

   return {
      fn = function() return true end,
      args = {}
   }
end

return {
   commands = builtin,
}
