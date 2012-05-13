-- lib/lace/compiler.lua
--
-- Lua Access Control Engine - Ruleset compiler
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For licence terms, see COPYING
--

local lex = require "lace.lex"

local function _error(str, words)
   return false, { msg = str, words = words }
end

local function _fake_loader(ctx, name)
   return _error("Ruleset not found: " .. name, {1})
end

local function _loader(ctx)
   -- We know the context is a table with a .lace table, so retrieve
   -- the loader function.  If it's absent, return a loader which
   -- fails due to no loader being present.
   return ctx[".lace"].loader or _fake_loader
end

local function normalise_error(ctx, err)
   -- For now, just return the string
   return err.msg
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
	 return false, normalise_error(compcontext, content)
      end
   end

   -- We have some content, let's lex it.
   -- We cannot fail to lex a string, it's not possible in our API
   local lexed_content = lex.string(content, sourcename)

   -- Now define the basis ruleset
   local ruleset = {
      name = sourcename,
      content = lexed_content,
      rules = {},
   }
   
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