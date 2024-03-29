-- lib/lace/error.lua
--
-- Lua Access Control Engine - Error management
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For licence terms, see COPYING
--

--- Error routines for Lace ruleset compilers and runtime engines.
--
-- Errors are a critical part of anything user-facing.  Lace works very
-- hard to ensure that it can report errors effectively so that the author
-- of the ruleset (the user of the application which is using Lace) can work
-- out what went wrong and how to fix it.

--- Report an error.
--
-- Report an error, including indicating which words caused the problem.
-- The words are 1-indexed from the start of whatever routine is trying
-- to consume words.
--
-- @tparam string str The error message.
-- @tparam {number,...}|nil words A list of the words causing this error.
-- @tparam boolean rnil Whether to return nil (indicating a programming error).
-- @treturn boolean|nil,table The compilation result (false or nil) and a
-- compilation error table
-- @function error
local function _error(str, words, rnil)
   local ret = false
   if rnil then
      ret = nil
   end
   return ret, { msg = str, words = words or {} }
end

--- Offset an error's recorded wordset.
--
-- Since errors carry word indices, if the layers of the compiler or runtime
-- alter the offsets, this routine can be used to offset the word indices
-- in an error message.
--
-- @tparam table err The error table
-- @tparam number offs The offset by which to adjust the error words.
-- @treturn table The error table (mutated by the offset).
-- @function offset
local function _offset(err, offs)
   if not err.words then
      err.words = {}
   end
   for k, w in ipairs(err.words) do
      if type(w) == "table" then
         err.words[k] = {nr = w.nr + offs, sub=w.sub}
      else
         err.words[k] = w + offs
      end
   end
   return err
end

--- Augment an error with source information
--
-- In order for errors to be useful they need to be augmented with the source
-- document in which they occurred and the line number on which they occurred.
-- This function allows the compiler (or runtime) to do just that.
--
-- @tparam table err The error table to augment
-- @tparam table source The lexically analysed source document.
-- @tparam linenr number The line number on which the error occurred.
-- @treturn table The error table (mutated with the source information).
-- @function augment
local function _augment(err, source, linenr)
   err.words.source = source
   err.words.linenr = linenr
   return err
end

local function _subwords(err, word)
   local subwords = err.words
   if subwords and #subwords > 0 then
      return {nr = word, sub = subwords}
   else
      return word
   end
end

--- Render an error down to a string.
--
-- Error tables carry a message, an optional set of words which caused the
-- error (if known) and a lexically analysed source and line number.
--
-- This function renders that information down to a multiline string which can
-- usefully be presented to the user of an application using Lace for access
-- control.
--
-- @tparam table err The error table.
-- @treturn string A multiline string rendering of the error.
-- @function render
local function _render(err)
   -- A rendered error has four lines
   -- The first line is the error message
   local ret = { err.msg }

   local wordset = {}
   local function build_wordset(words, wordset, parent_source, parent_linenr) --luacheck: ignore 431/wordset
      wordset.source = words.source or parent_source
      wordset.linenr = words.linenr or parent_linenr
      for _, word in ipairs(words) do
         if type(word) ~= "table" then
            wordset[word] = true
         else
            local subwordset = {}
            build_wordset(word.sub, subwordset, wordset.source, wordset.linenr)
            wordset[word.nr] = subwordset
         end
      end
   end
   build_wordset(err.words, wordset)

   local linelist = {}
   local function build_linelist(wordset, parent_source, parent_linenr) --luacheck: ignore 431/wordset
      if parent_source ~= wordset.source or parent_linenr ~= wordset.linenr then
         linelist[#linelist+1] = wordset
      end
      local srcline = wordset.source.lines[wordset.linenr] or {
         original = "???", content = { {spos = 1, epos = 3, str = "???"} }
      }
      for w, info in ipairs(srcline.content) do
         -- TODO: Sometimes wordset is table, but token has no subwords.
         if type(wordset[w]) == "table" and info.sub then
            build_linelist(wordset[w], wordset.source, wordset.linenr)
         end
      end
   end
   build_linelist(wordset)

   local function mark_my_words(line, wordset) --luacheck: ignore 431/wordset
      local hlstr, cpos = "", 1
      for w, info in ipairs(line) do
         -- Ensure that we're up to the start position of the word
         while (cpos < info.spos) do
            hlstr = hlstr .. " "
            cpos = cpos + 1
         end
         --  The subword can be defined in a different line entirely,
         --  at which point it's not a subword of word in this line.
         --  This is the norm for explicit definitions.
         if info.sub and type(wordset[w]) == "table"
         and wordset[w].source == wordset.source
         and wordset[w].linenr == wordset.linenr then
            -- space for [
            hlstr, cpos = hlstr .. " ", cpos + 1

            -- mark subword
            local subhlstr, subcpos = mark_my_words(info.sub, wordset[w])
            hlstr = hlstr .. subhlstr
            cpos = cpos + subcpos

            -- space for ]
            hlstr, cpos = hlstr .. " ", cpos + 1
         else
            -- Highlight this word if appropriate
            while (cpos <= info.epos) do
               hlstr = hlstr .. (wordset[w] and "^" or " ")
               cpos = cpos + 1
            end
         end
      end
      return hlstr, cpos
   end

   for _, wordset in ipairs(linelist) do --luacheck: ignore 421/wordset
      ret[#ret+1] = wordset.source.source .. " :: " .. tostring(wordset.linenr)
      local srcline = wordset.source.lines[wordset.linenr] or {
         original = "???", content = { {spos = 1, epos = 3, str = "???"} }
      }
      ret[#ret+1] = srcline.original
      local hlstr, _ = mark_my_words(srcline.content, wordset)
      ret[#ret+1] = hlstr
   end

   -- The rendered error is those strings joined by newlines
   return table.concat(ret, "\n")
end

return {
   error = _error,
   offset = _offset,
   augment = _augment,
   subwords = _subwords,
   render = _render,
}
