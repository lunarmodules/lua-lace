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

local unconditional_result, last_result

local function get_set_last_unconditional_result(newv)
   local ret = unconditional_result
   unconditional_result = newv
   return ret
end

local function get_set_last_result(newv)
   local ret = last_result
   last_result = newv
   return ret
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

   local cond = {...}
   if #cond == 0 then
      unconditional_result = result
   end
   last_result = result

   return {
      fn = _do_return,
      args = { result, reason, cond }
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
   
   local uncond, last = unconditional_result, last_result
   compcontext[".lace"].default = _return(compcontext, result, reason)
   unconditional_result, last_result = uncond, last

   return {
      fn = function() return true end,
      args = {}
   }
end

return {
   commands = builtin,
   get_set_last_unconditional_result = get_set_last_unconditional_result,
   get_set_last_result = get_set_last_result,
}
