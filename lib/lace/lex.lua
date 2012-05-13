-- lib/lace/lex.lua
--
-- Lua Access Control Engine -- Ruleset lexer
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For Licence terms, see COPYING
--

local sio = require "luxio.simple"

local function lex_one_line(line)
   local r = {}
   local acc = ""
   local c
   local escaping = false
   local quoting = false
   local spos, cpos = 1, 0
   while #line > 0 do
      c, line = line:match("^(.)(.*)$")
      cpos = cpos + 1
      if escaping then 
	 if quoting then
	    if c == "n" then
	       acc = acc .. "\n"
	    elseif c == "t" then
	       acc = acc .. "\t"
	    else
	       acc = acc .. c
	    end
	 else
	    acc = acc .. c
	 end
	 escaping = false
      else
	 if c == "'" and quoting == false then
	    -- Start single quotes
	    quoting = c
	 elseif c == '"' and quoting == false then
	    -- Start double quotes
	    quoting = c
	 elseif c == "'" and quoting == c then
	    -- End single quotes
	    quoting = false
	 elseif c == '"' and quoting == c then
	    -- End double quotes
	    quoting = false
	 elseif c == "\\" then
	    -- A backslash, entering escaping mode
	    escaping = true
	 elseif quoting then
	    -- Within quotes, so accumulate
	    acc = acc .. c
	 elseif c == " " or c == "\t" then
	    -- A space (or tab) and not quoting, so clear the accumulator
	    if acc ~= "" then
	       r[#r+1] = { spos = spos, epos = cpos - 1, str = acc }
	       spos = cpos + 1
	    elseif cpos == spos then
	       -- Increment the start position since we've not found a word yet
	       spos = spos + 1
	    end
	    acc = ""
	 else
	    acc = acc .. c
	 end
      end
   end
   if acc ~= "" then
      r[#r+1] = { spos = spos, epos = cpos, str = acc }
   end

   local warnings = {}
   if quoting then
      warnings[#warnings+1] = "Un-terminated quoted string"
   end
   if escaping then
      warnings[#warnings+1] = "Un-used escape at end"
   end

   return r, warnings
end

local function lex_a_ruleset(ruleset, sourcename)
   local lines = {}
   local ret = { source = sourcename, lines = lines }
   local n = 1
   local warn
   if ruleset:match("[^\n]$") then
      ruleset = ruleset .. "\n"
   end
   for oneline in ruleset:gmatch("([^\n]*)\n") do
      local linetab = { original = oneline }
      if oneline:match("^[ \t]*#") or
	 oneline:match("^[ \t]*//") or
	 oneline:match("^[ \t]*%-%-") then
	 linetab.type = "comment"
      elseif oneline:match("^[ \t]*$") then
	 linetab.type = "whitespace"
      else
	 linetab.type = "rule"
	 linetab.content, warn = lex_one_line(oneline)
	 if #warn > 0 then
	    linetab.warnings = warn
	 end
      end
      lines[n] = linetab
      n = n + 1
   end
   return ret
end

return {
   string = lex_a_ruleset,
}
