-- lib/lace/compiler.lua
--
-- Lua Access Control Engine - Ruleset compiler
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For licence terms, see COPYING
--

local lex = require "lace.lex"
local builtin = require "lace.builtin"

local function _error(str, words)
   return false, { msg = str, words = words }
end

local function _fake_loader(ctx, name)
   return _error("Ruleset not found: " .. name, {1})
end

local function _fake_command(ctx)
   return _error("Command is disabled by context")
end

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

local function _normalise_error(ctx, err)
   -- For now, just return the string
   return err.msg
end

local function _setposition(context, ruleset, linenr)
   context._lace.source = (ruleset or {}).content
   context._lace.linenr = linenr
end

local function compile_one_line(compcontext, line)
   -- The line is a rule, so we don't need to think about that.  The
   -- first entry is a command.
   local cmdname = line.content[1].str
   local cmdfn = _command(compcontext, cmdname)
   if type(cmdfn) ~= "function" then
      return _error("Unknown command: " .. cmdname, {1})
   end

   local args = {}
   for i = 1, #line.content do
      args[i] = line.content[i].str
   end

   return cmdfn(compcontext, unpack(args))
end

local function internal_compile_ruleset(compcontext, sourcename, content, suppress_default)
   assert(type(compcontext) == "table", "Compilation context must be a table")
   assert(type(compcontext._lace) == "table", "Compilation context must contain a _lace table")
   assert(type(sourcename) == "string", "Source name must be a string")
   assert(content == nil or type(content) == "string", "Content must be nil or a string")
   if not content then
      -- No content supplied, try and load it.
      sourcename, content = _loader(compcontext)(compcontext, sourcename)
      if type(sourcename) ~= "string" then
	 return false, _normalise_error(compcontext, content)
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
	 local rule, msg = compile_one_line(compcontext, line)
	 if type(rule) ~= "table" then
	    return rule, (rule == nil) and msg or _normalise_error(compcontext, msg)
	 end
	 rule.linenr = i
	 ruleset.rules[#ruleset.rules+1] = rule
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
   if not suppress_default and not uncond and not result then
      return false, "No result set whatsoever"
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

local function compile_ruleset(ctx, src, cnt)
   local ok, ret, msg = xpcall(function() 
				  return internal_compile_ruleset(ctx, src, cnt) 
			       end, debug.traceback)
   if not ok then
      return nil, ret
   end

   if type(msg) == "table" then
      -- TODO: Extract position information etc from error and
      -- formulate a gorgeous multiline error message.
      msg = msg.msg or "Empty error"
   end

   return ret, msg
end

return {
   internal_loader = _loader,
   internal_compile = internal_compile_ruleset,
   compile = compile_ruleset,
   error = _error,
}
