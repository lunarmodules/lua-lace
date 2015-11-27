-- lib/lace/compiler.lua
--
-- Lua Access Control Engine - Ruleset compiler
--
-- Copyright 2012,2015 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For licence terms, see COPYING
--

--- The compiler for the Lua Access Control engine.
--
-- Lace works hard to give you good error message information when encountering
-- problems with your rulesets.  The compiler gathers a lot of debug
-- information and stores it alongside the compiled ruleset.

local lex = require "lace.lex"
local builtin = require "lace.builtin"
local err = require "lace.error"

local unpack = unpack or table.unpack

local function _fake_loader(ctx, name)
   return err.error("Ruleset not found: " .. name, {1})
end

local function _fake_command(ctx)
   return err.error("Command is disabled by context")
end

--- Internal loader abstraction.
--
-- Used by `lace.builtin.commands.include`, this function returns a loader
-- which can be used to acquire more content during compilation of a Lace
-- ruleset.
--
-- @tparam table ctx The Lace compiliation context
-- @treturn function A loader function
-- @function internal_loader
local function _loader(ctx)
   -- We know the context is a table with a _lace table, so retrieve
   -- the loader function.  If it's absent, return a loader which
   -- fails due to no loader being present.
   return ctx._lace.loader or _fake_loader
end

local function _command(ctx, name)
   -- While we know _lace is present, there's no guarantee they added
   -- any commands
   local cmdtab = ctx._lace.commands or {}
   local cfn = cmdtab[name]
   if cfn == nil then
      cfn = builtin.commands[name]
   elseif cfn == false then
      cfn = _fake_command
   end
   return cfn
end

local function _setposition(context, ruleset, linenr)
   context._lace.source = (ruleset or {}).content
   context._lace.linenr = linenr
end

local function transfer_args(compcontext, content, rules)
   local args = {}
   for i = 1, #content do
      if content[i].sub then
	 local sub = content[i].sub
	 local defnr = compcontext._lace.magic_define_nr
	 local definename = "__autodef"..tostring(defnr)
	 compcontext._lace.magic_define_nr = defnr + 1
	 local definefn = _command(compcontext, "define")
	 local subargs
	 rules, subargs = transfer_args(compcontext, sub, rules)
	 if type(rules) ~= "table" then
	    return rules, subargs
	 end
	 local definerule, msg = definefn(compcontext, "define", definename,
					  unpack(subargs))
	 if type(definerule) ~= "table" then
	    -- for now, we lock the error to the whole sublex
	    msg.words = {i}
	    return definerule, msg
	 end
	 args[#args+1] = definename
	 rules[#rules+1] = definerule
      else
	 args[#args+1] = content[i].str
      end
   end
   return rules, args
end

local function compile_one_line(compcontext, line)
   -- The line is a rule, so we don't need to think about that.  The
   -- first entry is a command.
   local cmdname = line.content[1].str
   local cmdfn = _command(compcontext, cmdname)
   if type(cmdfn) ~= "function" then
      return err.error("Unknown command: " .. cmdname, {1})
   end

   local rules, args = transfer_args(compcontext, line.content, {})
   if type(rules) ~= "table" then
      return rules, args
   end
   
   local linerule, err = cmdfn(compcontext, unpack(args))
   if type(linerule) ~= "table" then
      return linerule, err
   end
   rules[#rules+1] = linerule
   return rules, err
end

--- Internal ruleset compilation.
--
-- Internal ruleset compilation function.  This function should not be used
-- except from compilation commands such as `lace.builtin.commands.include`.
-- This function is much less forgiving of issues than `lace.compiler.compile`.
--
-- @tparam table compcontext Compilation context
-- @tparam string sourcename Source name
-- @tparam string content Source content
-- @tparam boolean suppress_default Suppress the use of a default rule.
-- @treturn table Compiled Lace ruleset
-- @function internal_compile
local function internal_compile_ruleset(compcontext, sourcename, content, suppress_default)
   assert(type(compcontext) == "table", "Compilation context must be a table")
   assert(type(compcontext._lace) == "table", "Compilation context must contain a _lace table")
   assert(type(sourcename) == "string", "Source name must be a string")
   assert(content == nil or type(content) == "string", "Content must be nil or a string")
   if not content then
      -- No content supplied, try and load it.
      sourcename, content = _loader(compcontext)(compcontext, sourcename)
      if type(sourcename) ~= "string" then
	 if not suppress_default then
	    -- We're not suppressing default which implies we're
	    -- the first out of the gate, so we need
	    -- to offset to account for the implicit include
	    err.offset(content, 1)
	 end
	 return false, err.augment(content, compcontext._lace.source, compcontext._lace.linenr)
      end
   end

   -- We have some content, let's lex it.
   -- We cannot fail to lex a string, it's not possible in our API
   local lexed_content = lex.string(content, sourcename)

   -- Now define the basis ruleset
   local ruleset = {
      content = lexed_content,
      rules = {},
   }
   
   local prev_uncond_result = builtin.get_set_last_unconditional_result()
   local prev_result = builtin.get_set_last_result()

   if not suppress_default then
      -- Ensure there's no default present before processing.
      -- We only suppress inside includes
      compcontext._lace.default = nil
   end

   for i = 1, #lexed_content.lines do
      local line = lexed_content.lines[i]
      if line.type == "rule" then
	 -- worth trying to parse a rule
	 _setposition(compcontext, ruleset, i)
	 local rules, msg = compile_one_line(compcontext, line)
	 if type(rules) ~= "table" then
	    return rules, err.augment(msg, ruleset.content, i)
	 end
	 for j = 1, #rules do
	    local rule = rules[j]
	    rule.linenr = i
	    rule.source = ruleset.content
	    ruleset.rules[#ruleset.rules+1] = rule
	 end
      end
   end

   -- And restore the builtin result (in case we were chained/included)
   local uncond = builtin.get_set_last_unconditional_result(prev_uncond_result)
   local result = builtin.get_set_last_result(prev_result)
   -- Finally consider the default behaviour
   -- Cases to consider are:
   --   There's an unconditional result, in which case no problem
   --   There's no result whatsoever, conditional or otherwise, error out
   --   There's no unconditional result but there's a default
   --     in which case use the default
   --   There's no unconditional result and no default, fake up a default and
   --     then use it.
   if not suppress_default and not uncond and not result and not compcontext._lace.default then
      local _, nores = err.error("No result set whatsoever", {})
      return false, err.augment(nores, ruleset.content, #ruleset.content.lines + 1)
   end

   if not suppress_default and not uncond then
      if not compcontext._lace.default then
	 -- No default, fake one up
	 builtin.commands.default(compcontext, "default",
				  result == "allow" and "deny" or "allow")
      end
      -- Now, inject the default command at the end of the ruleset.
      ruleset.rules[#ruleset.rules+1] = compcontext._lace.default
   end

   _setposition(compcontext)
   return ruleset
end

--- Compile a lace ruleset.
--
-- Compile a lace ruleset so that it can be executed by `lace.engine.run`
-- later.  If you provide content then it is compiled using the source name as
-- the name used in error messages.  If you do not supply any content then Lace
-- will construct an implicit include of the given source name.
--
-- @tparam table ctx Compilation context
-- @tparam string src Source name
-- @tparam ?string cnt Source contents (nil to cause an implicit
--                                      include of _src_)
-- @treturn table Compiled Lace ruleset
-- @function compile
local function compile_ruleset(ctx, src, cnt)
   -- Augment the compiler context with a false
   -- source so that we can be sure the expect early errors to stand a chance
   if ctx and src and not cnt then
      if type(ctx._lace) ~= "table" then
	 return nil, "Compilation context must contain a _lace table"
      end
      ctx._lace.source = {
	 source = "Implicit inclusion of " .. src,
	 lines = { {
	       original = "include " .. src,
	       content = {
		  { spos = 1, epos = 7, content = "include" },
		  { spos = 9, epos = 8 + #src, content = src }
	       }
	    }
	 }
      }
      ctx._lace.linenr = 1
      ctx._lace.magic_define_nr = 1
   end
   local ok, ret, msg = xpcall(function() 
				  return internal_compile_ruleset(ctx, src, cnt) 
			       end, debug.traceback)
   if not ok then
      return nil, ret
   end

   assert((ret) or (type(msg) == "table"), "Prenormalised error! " .. tostring(msg))

   if type(msg) == "table" then
      assert(type(msg.msg) == "string", "No error message")
      msg = err.render(msg)
   end

   return ret, msg
end

return {
   internal_loader = _loader,
   internal_compile = internal_compile_ruleset,
   compile = compile_ruleset,
}
