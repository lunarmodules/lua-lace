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
local err = require "lace.error"

local function compiler()
   return require "lace.compiler"
end

local function run_conditions(exec_context, cond, anyof)
   local anymet = false
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
	 -- condition failed
	 if not anyof then
	    return false
	 end
      else
	 anymet = true
      end
   end
   -- conditions passed
   if anyof then
      return anymet
   end
   return true
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
   local pass, msg = run_conditions(exec_context, cond)
   if pass == nil then
      -- Pass errors
      return nil, msg
   elseif pass == false then
      -- Conditions failed, return true to continue execution
      return true
   end
   return result, reason
end

local function _return(compcontext, result, reason, ...)
   if result ~= "allow" and result ~= "deny" then
      return err.error("Unknown result: " .. result, {1})
   end
   if type(reason) ~= "string" then
      return err.error("Expected reason, got nothing", {1})
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
      return err.error("Expected result, got nothing", {1})
   end
   if result ~= "allow" and result ~= "deny" then
      return err.error("Result wasn't allow or deny", {2})
   end
   if type(reason) ~= "string" then
      reason = "Default behaviour"
   end
   if unwanted ~= nil then
      return err.error("Unexpected additional content", {4})
   end

   if compcontext._lace.default then
      return err.error("Cannot change the default", {1, 2})
   end
   
   local uncond, last = unconditional_result, last_result
   compcontext._lace.default = _return(compcontext, result, reason)
   unconditional_result, last_result = uncond, last

   return {
      fn = function() return true end,
      args = {}
   }
end

--[ Control types ]--------------------------------------------------

local function _compile_any_all_of(compcontext, mtype, first, second, ...)
   if type(first) ~= "string" then
      return err.error("Expected at least two names, got none", {1})
   end
   if type(second) ~= "string" then
      return err.error("Expected at least two names, only got one", {1, 2})
   end

   return {
      fn = run_conditions,
      args = { { first, second, ...}, mtype == "anyof" }
   }
end

local builtin_control_fn = {
   anyof = _compile_any_all_of,
   allof = _compile_any_all_of
}

--[ Definitions ]----------------------------------------------------

local function _controlfn(ctx, name)
   local ctt = ctx._lace.controltype or {}
   local cfn = ctt[name]
   if cfn == nil then
      cfn = builtin_control_fn[name]
   end
   return cfn
end

function builtin.define(compcontext, define, name, controltype, ...)
   if type(name) ~= "string" then
      return err.error("Expected name, got nothing")
   end

   if name == "" or name:sub(1,1) == "!" then
      return err.error("Bad name for definition", {2})
   end

   if type(controltype) ~= "string" then
      return err.error("Expected control type, got nothing")
   end
   
   local controlfn = _controlfn(compcontext, controltype)
   if not controlfn then
      return err.error("Unknown control type: " .. controltype, {3})
   end

   local ctrltab, msg = controlfn(compcontext, controltype, ...)
   if type(ctrltab) ~= "table" then
      -- offset all the words in the error by 2 (for define and name)
      msg = err.offset(msg, 2)
      return false, msg
   end

   -- Successfully created a control table, return a rule for it
   return {
      fn = engine.define,
      args = { name, ctrltab }
   }
end

builtin.def = builtin.define

--[ Inclusion of rulesets ]-------------------------------------------

local function _do_include(exec_context, ruleset, conds)
   local pass, msg = run_conditions(exec_context, conds)
   if pass == nil then
      -- Pass errors
      return nil, msg
   elseif pass == false then
      -- Conditions failed, return true to continue execution
      return true
   end
   -- Essentially we run the ruleset and return its values
   local result, msg = engine.internal_run(ruleset, exec_context)
   if result == "" then
      return true
   end
   return result, msg
end

function builtin.include(comp_context, cmd, file, ...)
   local safe_if_not_present = cmd:sub(-1) == "?"

   local conds = {...}
   
   if type(file) ~= "string" then
      return err.error("No file named for inclusion")
   end

   local loader = compiler().internal_loader(comp_context)
   local real, content = loader(comp_context, file)

   if not real then
      -- Could not find the file
      if safe_if_not_present then
	 -- Include file was not present, just return an empty command
	 return {
	    fn = function() return true end,
	    args = {}
	 }
      end
      -- Otherwise, propagate the error
      return real, content
   end
   
   -- Okay, the file is present, let's parse it.
   local ruleset, msg = compiler().internal_compile(comp_context, real, content, true)
   if type(ruleset) ~= "table" then
      return false, msg
   end
   
   -- Okay, we parsed, so build the runtime
   return {
      fn = _do_include,
      args = { ruleset, conds }
   }
end

return {
   commands = builtin,
   get_set_last_unconditional_result = get_set_last_unconditional_result,
   get_set_last_result = get_set_last_result,
}
