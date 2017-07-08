-- lib/lace/builtin.lua
--
-- Lua Access Control Engine -- Builtin commands for Lace
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For Licence terms, see COPYING
--

--- Lace builtin commands and match types.
--
-- The builtin match types and commands provided by Lace.  These commands and
-- match types are supported automatically by all lace compiles.  The builtin
-- command `default` and the builtin commands `allow` and `deny` collude with
-- the compiler to ensure that all compiled rulesets will always either
-- explicitly allow or deny access.

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
	 msg.words = {err.subwords(msg, i)}
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

--- Internal function to get/set the last result for unconditional access.
--
-- The last result (unconditional only) is stored so that defaults can be
-- processed in the absence of a `default` statement.
--
-- This function exists to collude with `lace.compiler.internal_compile` so
-- that it can synthesise default access statements if needed.
--
-- @tparam string|nil newv The new value for the last access result.
--                         It should be one of `allow`, `deny` or a _nil_.
-- @treturn string|nil The old (current) value for the last access result.
-- @function get_set_last_unconditional_result
local function get_set_last_unconditional_result(newv)
   local ret = unconditional_result
   unconditional_result = newv
   return ret
end

--- Internal function to get/set the last result for access.
--
-- The last result (conditional perhaps) is stored so that defaults can be
-- processed in the absence of a `default` statement.
--
-- This function exists to collude with `lace.compiler.internal_compile` so
-- that it can synthesise default access statements if needed.
--
-- @tparam string|nil newv The new value for the last access result.
--                         It should be one of `allow`, `deny` or a _nil_.
-- @treturn string|nil The old (current) value for the last access result.
-- @function get_set_last_result
local function get_set_last_result(newv)
   local ret = last_result
   last_result = newv
   return ret
end

local function _do_return(exec_context, rule, result, reason, cond)
   local pass, msg = run_conditions(exec_context, cond)
   if pass == nil then
      -- Pass errors
      msg = err.offset(msg, 2)
      -- Record error source
      msg = err.augment(msg, rule.source, rule.linenr)
      return nil, msg
   elseif pass == false then
      -- Conditions failed, return true to continue execution
      return true
   end
   return result, reason
end

--- Compile an `allow` or `deny`.
--
-- (_Note: this is also `commands.deny`_)
--
-- Allowing and denying access is, after all, what access control lists are all
-- about.  This function compiles in an `allow` or `deny` statement including
-- noting what kind of access statement it is and what 
--
-- @tparam table compcontext The compilation context
-- @tparam string result The result to be compiled (`allow` or `deny`).
-- @tparam string reason The reason to be returned to the user for this.
-- @tparam[opt] string ... The conditions placed on this `allow` or `deny`.
-- @treturn table The compiled `allow`/`deny`.
-- @function commands.allow
-- @alias commands.deny
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
   else
      compcontext._lace.defined = (compcontext._lace.defined or {})
      for i, dname in ipairs(cond) do
	 if dname:sub(1,1) == "!" then
	    dname = dname:sub(2)
	 end
	 if not compcontext._lace.defined[dname] then
	    return err.error("Undefined name used in condition ("..dname..")", {i+2})
	 end
      end
   end
   last_result = result

   local rule = {
      fn = _do_return,
   }
   rule.args = { rule, result, reason, cond }
   return rule
end

builtin.allow = _return
builtin.deny = _return

--[ Default for Allow and Deny ]------------------------------------

--- Compile a `default` command.
--
-- All rulesets must, ultimately, allow or deny access.  The `default` command
-- allows rulesets to define whether they are permissive (defaulting to
-- `allow`) or proscriptive (defaulting to `deny`).
--
-- In addition, setting default causes a record to be made, preventing
-- additional attempts to set a default access mode.  This ensures that once
-- the default has been selected, additional ruleset included (perhaps from
-- untrusted sources) cannot change the default behaviour.
--
-- @tparam table compcontext The compilation context
-- @tparam string def The command which triggered this compilation. (`default`)
-- @tparam string result The default result (`allow` or `deny`)
-- @tparam string reason The reason to be given.
-- @tparam[opt] * unwanted If _unwanted_ is anything but nil, an error occurs.
-- @treturn table A null command
-- @function commands.default
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
   local default_rule = _return(compcontext, result, reason)
   -- Normally lace.compiler.internal_compile augments the rules with sources,
   -- but since this rule is not returned, we have to augment it ourselves.
   default_rule.source = compcontext._lace.source
   default_rule.linenr = compcontext._lace.linenr
   compcontext._lace.default = default_rule
   unconditional_result, last_result = uncond, last

   return {
      fn = function() return true end,
      args = {}
   }
end

--[ Control types ]--------------------------------------------------

local function _do_any_all_of(exec_context, rule, cond, anyof)
   local pass, msg = run_conditions(exec_context, cond, anyof)
   if pass == nil then
      -- Offset error location by anyof/allof word
      msg = err.offset(msg, 1)
      -- Record error source
      msg = err.augment(msg, rule.source, rule.linenr)
      return nil, msg
   end
   return pass, msg
end

local function _compile_any_all_of(compcontext, mtype, first, second, ...)
   if type(first) ~= "string" then
      return err.error("Expected at least two names, got none", {1})
   end
   if type(second) ~= "string" then
      return err.error("Expected at least two names, only got one", {1, 2})
   end

   -- Now check that all the arguments we were given make sense...
   local cond = {first, second, ...}
   compcontext._lace.defined = (compcontext._lace.defined or {})
   for i, dname in ipairs(cond) do
      if dname:sub(1,1) == "!" then
	 dname = dname:sub(2)
      end
      if not compcontext._lace.defined[dname] then
	 return err.error("Undefined name used in "..mtype.." ("..dname..")", {i + 1})
      end
   end

   local rule =  {
      fn = _do_any_all_of,
   }
   rule.args = { rule, cond, mtype == "anyof" }
   return rule
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

local function wrap_call_definition_location(rule, defn)
   local fn = defn.fn
   function defn.fn(...)
      local res, msg = fn(...)
      if res == nil then
         msg = err.offset(msg, 2)
         msg = err.augment(msg, rule.source, rule.linenr)
         return nil, msg
      end
      return res, msg
   end
   return defn
end

local function _do_define(exec_context, rule, name, defn)
   defn = wrap_call_definition_location(rule, defn)
   local res, msg = engine.define(exec_context, name, defn)
   if res == nil then
      msg = err.augment(msg, rule.source, rule.linenr)
      return nil, msg
   end
   return res, msg
end

--- Compile a definition command
--
-- Definitions are a core behaviour of Lace.  This builtin allows the ruleset
-- to define additional conditions on which `allow`, `deny` and `include` can
-- operate.  
--
-- @tparam table compcontext The compilation context.
-- @tparam string define The word which triggered this compilation command.
--                       (`define`)
-- @tparam string name The name being defined.
-- @tparam string controltype The control type to be used. (Such as `anyof`,
--                            `allof` or any of the match types defined by
--                            the caller of the compiler).
-- @tparam[opt] string ... The content of the definition (consumed by the
--                         match type compiler).
-- @treturn table The compiled definition command.
-- @function commands.define
-- @alias commands.def
function builtin.define(compcontext, define, name, controltype, ...)
   if type(name) ~= "string" then
      return err.error("Expected name, got nothing", {1})
   end

   if name == "" or name:sub(1,1) == "!" then
      return err.error("Bad name for definition", {2})
   end

   if type(controltype) ~= "string" then
      return err.error("Expected control type, got nothing", {1, 2})
   end

   local controlfn = _controlfn(compcontext, controltype)
   if not controlfn then
      emsg = "%s's second parameter (%s) must be a control type such as anyof"
      return err.error(emsg:format(define, controltype), {3})
   end

   local ctrltab, msg = controlfn(compcontext, controltype, ...)
   if type(ctrltab) ~= "table" then
      -- offset all the words in the error by 2 (for define and name)
      msg = err.offset(msg, 2)
      return false, msg
   end

   -- Note the define name for checking by other control types
   compcontext._lace.defined = (compcontext._lace.defined or {})
   compcontext._lace.defined[name] = true

   -- Successfully created a control table, return a rule for it
   local rule = {
      fn = _do_define,
   }
   rule.args = { rule, name, ctrltab }
   return rule
end

builtin.def = builtin.define

--[ Inclusion of rulesets ]-------------------------------------------

local function _do_include(exec_context, rule, ruleset, conds)
   local pass, msg = run_conditions(exec_context, conds)
   if pass == nil then
      -- Propagate errors
      msg = err.offset(msg, 2)
      msg = err.augment(msg, rule.source, rule.linenr)
      return nil, msg
   elseif pass == false then
      -- Conditions failed, return true to continue execution
      return true
   end
   -- Essentially we run the ruleset and return its values
   local result, msg = engine.internal_run(ruleset, exec_context)
   if result == "" then
      return true
   elseif result == nil then
      msg.words = {err.subwords(msg, 2)}
      msg = err.augment(msg, rule.source, rule.linenr)
      return nil, msg
   end
   return result, msg
end

--- Compile an `include` command.
--
-- Compile a lace `include` command.  This uses the exported internal loader
-- function `lace.compiler.internal_loader` to find a loader and if it finds
-- one, it uses the internal compilation function
-- `lace.compiler.internal_compile` to compile the loaded source before
-- constructing a runtime "inclusion" which deals with the conditions before
-- running the sub-ruleset if appropriate.
--
-- Regardless of the conditions placed on the include statement, includes are
-- always processed during compilation.
--
-- @tparam table comp_context The compilation context
-- @tparam string cmd The command which triggered this include command.
--                    (`include` or `include?`)
-- @tparam string file The file (source name) to include.
-- @tparam[opt] string ... Zero or more conditions under which the included
--                         content will be run by the engine.  If there are no
--                         conditions then the include is unconditional.
-- @treturn table The compiled inclusion command.
-- @function commands.include
function builtin.include(comp_context, cmd, file, ...)
   local safe_if_not_present = cmd:sub(-1) == "?"

   local conds = {...}
   
   if type(file) ~= "string" then
      return err.error("No ruleset named for inclusion", {1})
   end

   -- Check the conditions are defined
   comp_context._lace.defined = (comp_context._lace.defined or {})
   for i, dname in ipairs(conds) do
      if dname:sub(1,1) == "!" then
	 dname = dname:sub(2)
      end
      if not comp_context._lace.defined[dname] then
	 return err.error("Undefined name used in include condition ("..dname..")", {i+1})
      end
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
      err.offset(content, 1)
      return real, content
   end
   
   -- Okay, the file is present, let's parse it.
   local ruleset, msg = compiler().internal_compile(comp_context, real, content, true)
   if type(ruleset) ~= "table" then
      -- Propagation of the error means rendering and taking ownership...
      return err.error(err.render(msg) .. "\nwhile including " .. file, {2})
   end
   
   -- Okay, we parsed, so build the runtime
   local rule = {
      fn = _do_include,
   }
   rule.args = { rule, ruleset, conds }
   return rule
end

return {
   commands = builtin,
   get_set_last_unconditional_result = get_set_last_unconditional_result,
   get_set_last_result = get_set_last_result,
}
