-- lib/lace/error.lua
--
-- Lua Access Control Engine - Error management
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For licence terms, see COPYING
--

local function _error(str, words, rnil)
   local ret = false
   if rnil then
      ret = nil
   end
   return ret, { msg = str, words = words or {} }
end

local function _offset(err, offs)
   if not err.words then
      err.words = {}
   end
   for k, w in ipairs(err.words) do
      err.words[k] = w + offs
   end
   return err
end

local function _augment(err, source, linenr)
   err.source = source
   err.linenr = linenr
end

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
