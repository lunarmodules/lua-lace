-- lib/lace/lex.lua
--
-- Lua Access Control Engine -- Ruleset lexer
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For Licence terms, see COPYING
--

--- Lace Internals - Ruleset lexer.
--
-- The lexer for Lace is only used internally and is generally not accessed
-- from outside of Lace.  It is exposed only for testing and validation
-- purposes.

local M = {}

local lexer_line_cache = {}

local lex_one_line

local function _lex_one_line(line, terminator)
   local r = {}
   local acc = ""
   local c
   local warnings = {}
   local escaping = false
   local quoting = false
   local force_empty = false
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
         if c == terminator and quoting == false then
            -- Reached the terminator, break out
            -- The terminator is not actually part of the last word in the line
            -- so we push back that character,
            -- since it's the only case we actually need to put any back.
            cpos = cpos - 1
            break
         elseif c == "'" and quoting == false then
            -- Start single quotes
            quoting = c
            force_empty = true
         elseif c == '"' and quoting == false then
            -- Start double quotes
            quoting = c
            force_empty = true
         elseif c == '[' and quoting == false then
            -- Something worth lexing
            local ltab, rest, warns = lex_one_line(line, "]")
            if warns then
                -- Add to our list of warnings
                for _, warning in ipairs(warns) do
                    warnings[#warnings+1] = warning;
                end
            end
            -- For now, assume the accumulator is good enough
            cpos = cpos + #line - #rest
            r[#r+1] = { spos = spos, epos = cpos, sub = ltab, acc = acc }
            spos = cpos + 1
            line = rest
            acc = ""
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
            if acc ~= "" or force_empty then
               r[#r+1] = { spos = spos, epos = cpos - 1, str = acc }
               spos = cpos + 1
               force_empty = false
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
   if acc ~= "" or force_empty then
      r[#r+1] = { spos = spos, epos = cpos, str = acc }
   end

   if quoting then
      warnings[#warnings+1] = "Un-terminated quoted string"
   end
   if escaping then
      warnings[#warnings+1] = "Un-used escape at end"
   end

   return r, line, warnings
end

function lex_one_line(line, terminator)
   local tag = line .. "\n" .. tostring(terminator)
   if not lexer_line_cache[tag] then
      lexer_line_cache[tag] = { _lex_one_line(line, terminator) }
   end
   return lexer_line_cache[tag][1], lexer_line_cache[tag][2], lexer_line_cache[tag][3]
end

local cached_full_lexes = {}

--- Lexically analyse a ruleset.
-- @tparam string ruleset The ruleset to lex.
-- @tparam string sourcename The name of the source to go into debug info.
-- @treturn table A list of lexed lines, each line being a table of tokens
-- with their associated debug information.
function M.string(ruleset, sourcename)
   if cached_full_lexes[sourcename] and
      cached_full_lexes[sourcename][ruleset] then
      return cached_full_lexes[sourcename][ruleset]
   end
   local lines = {}
   local ret = { source = sourcename, lines = lines }
   local n = 1
   local warn, rest_of_line
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
         linetab.content, rest_of_line, warn = lex_one_line(oneline)
         assert(rest_of_line == "", "Content left after line lexing")
         if #warn > 0 then
            linetab.warnings = warn
         end
      end
      lines[n] = linetab
      n = n + 1
   end
   cached_full_lexes[sourcename] = cached_full_lexes[sourcename] or {}
   cached_full_lexes[sourcename][ruleset] = ret
   return ret
end

return M
