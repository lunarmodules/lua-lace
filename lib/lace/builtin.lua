-- lib/lace/builtin.lua
--
-- Lua Access Control Engine -- Builtin commands for Lace
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For Licence terms, see COPYING
--

local builtin = {}

local engine = require "lace.engine"

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
   for i = 1, #cond do
      local name = cond[i]
      local invert = false
      if name:sub(1,1) == "!" then
	 invert = true
	 name = name:sub(2)
      end
      local res, msg = engine.test(exec_context, name)
      if res == nil then
	 return nil, msg
      end
      if invert then
	 res = not res
      end
      if not res then
	 -- condition failed, return true to continue execution
	 return true
      end
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

--[ Definitions ]----------------------------------------------------

local function _controlfn(ctx, name)
   local ctt = ctx[".lace"].controltype or {}
   return ctt[name]
end

function builtin.define(compcontext, define, name, controltype, ...)
   if type(name) ~= "string" then
      return compiler().error("Expected name, got nothing")
   end

   if name == "" or name:sub(1,1) == "!" then
      return compiler().error("Bad name for definition", {2})
   end

   if type(controltype) ~= "string" then
      return compiler().error("Expected control type, got nothing")
   end
   
   local controlfn = _controlfn(compcontext, controltype)
   if not controlfn then
      return compiler().error("Unknown control type", {3})
   end

   local ctrltab, msg = controlfn(compcontext, controltype, ...)
   if type(ctrltab) ~= "table" then
      -- offset all the words in the error by 2 (for define and name)
      if msg.words then
	 for i = 1, #msg.words do
	    msg.words[i] = msg.words[i] + 2
	 end
      end
      return false, msg
   end

   -- Successfully created a control table, return a rule for it
   return {
      fn = engine.define,
      args = { name, ctrltab }
   }
end

builtin.def = builtin.define

return {
   commands = builtin,
   get_set_last_unconditional_result = get_set_last_unconditional_result,
   get_set_last_result = get_set_last_result,
}
