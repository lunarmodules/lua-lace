-- lib/lace/compiler.lua
--
-- Lua Access Control Engine - Ruleset compiler
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For licence terms, see COPYING
--

local lex = require "lace.lex"

local builtin_commands = {}

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
   -- We know the context is a table with a .lace table, so retrieve
   -- the loader function.  If it's absent, return a loader which
   -- fails due to no loader being present.
   return ctx[".lace"].loader or _fake_loader
end

local function _command(ctx, name)
   -- While we know .lace is present, there's no guarantee they added
   -- any commands
   local cmdtab = ctx[".lace"].commands or {}
   local cfn = cmdtab[name]
   if cfn == nil then
      cfn = builtin_commands[name]
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
   context[".lace"].source = (ruleset or {}).content
   context[".lace"].linenr = linenr
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

local function internal_compile_ruleset(compcontext, sourcename, content)
   assert(type(compcontext) == "table", "Compilation context must be a table")
   assert(type(compcontext[".lace"]) == "table", "Compilation context must contain a .lace table")
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
   
   for i = 1, #lexed_content.lines do
      local line = lexed_content.lines[i]
      if line.type == "rule" then
	 -- worth trying to parse a rule
	 _setposition(compcontext, ruleset, i)
	 local rule, msg = compile_one_line(compcontext, line)
	 if type(rule) ~= "table" then
	    return rule, (rule == nil) and msg or _normalise_error(compcontext, msg)
	 end
	 ruleset.rules[#ruleset.rules+1] = rule
      end
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
   return ret, msg
end

return {
   compile = compile_ruleset,
   error = _error,
}