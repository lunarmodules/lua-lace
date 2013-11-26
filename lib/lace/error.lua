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
--                            compilation error table
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
      err.words[k] = w + offs
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
   err.source = source
   err.linenr = linenr
   return err
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
   -- The second is the source filename and line
   ret[2] = err.source.source .. " :: " .. tostring(err.linenr)
   -- The third line is the line of the input
   local srcline = err.source.lines[err.linenr] or {
      original = "???", content = { {spos = 1, epos = 3, str = "???"} }
   }
   ret[3] = srcline.original
   -- The fourth line is the highlight for each word in question
   local wordset = {}
   for _, word in ipairs(err.words) do
      wordset[word] = true
   end
   local hlstr = ""
   local cpos = 1
   for w, info in ipairs(srcline.content) do
      -- Ensure that we're up to the start position of the word
      while (cpos < info.spos) do
	 hlstr = hlstr .. " "
	 cpos = cpos + 1
      end
      -- Highlight this word if appropriate
      while (cpos <= info.epos) do
	 hlstr = hlstr .. (wordset[w] and "^" or " ")
	 cpos = cpos + 1
      end
   end
   ret[4] = hlstr
   -- The rendered error is those four strings joined by newlines
   return table.concat(ret, "\n")
end

return {
   error = _error,
   offset = _offset,
   augment = _augment,
   render = _render,
}
