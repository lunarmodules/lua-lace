-- test/test-lace.lua
--
-- Lua Access Control Engine -- Tests for the Lace error module
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For Licence terms, see COPYING
--

-- Step one, start coverage

pcall(require, 'luacov')

local error = require 'lace.error'

local testnames = {}

local real_assert = assert
local total_asserts = 0
local function assert(...)
   real_assert(...)
   total_asserts = total_asserts + 1
end

local function add_test(suite, name, value)
   rawset(suite, name, value)
   testnames[#testnames+1] = name
end

local suite = setmetatable({}, {__newindex = add_test})

function suite.error_formation()
   local words = {}
   local ret1, ret2 = error.error("msg", words)
   assert(ret1 == false, "First return of error() should be false")
   assert(type(ret2) == "table", "Second return of error() should be a table")
   assert(ret2.msg == "msg", "Message should be passed through")
   assert(ret2.words == words, "Words should be passed through")
end

function suite.error_offset()
   local words = {3,5}
   local f, err = error.error("msg", words)
   local nerr = error.offset(err, 2)
   assert(nerr == err, "Offset should return the same error it was given")
   assert(words[1] == 5, "Offset should alter the first word")
   assert(words[2] == 7, "Offset should alter all the words")
end

function suite.error_augmentation()
   local f, err = error.error("msg")
   local src = {}
   local aug = error.augment(err, src, 10)
   assert(aug == err, "Augmentation should return the error")
   assert(err.words.source == src, "Augmented errors should contain their source data")
   assert(err.words.linenr == 10, "Augmented errors should contain their error line")
end

function suite.error_render()
   local f, err = error.error("msg", {1, 3})
   local src = { source = "SOURCE", lines = {
	 {
	    original = "  ORIG LINE FISH",
	    content = {
	       { spos = 3, epos = 6, str = "ORIG" },
	       { spos = 8, epos = 11, str = "LINE" },
	       { spos = 13, epos = 16, str = "FISH" },
	    }
	 }
      }
   }
   error.augment(err, src, 1)
   local estr = error.render(err)
   local line1, line2, line3, line4 = estr:match("^([^\n]*)\n([^\n]*)\n([^\n]*)\n([^\n]*)$")
   assert(line1, "There is a line 1")
   assert(line2, "There is a line 2")
   assert(line3, "There is a line 3")
   assert(line4, "There is a line 4")
   assert(line1 == "msg", "The first line should be the error message")
   assert(line2 == "SOURCE :: 1", "The second line is where the error happened")
   assert(line3 == src.lines[1].original, "The third line is the original line")
   assert(line4 == "  ^^^^      ^^^^", "The fourth line highlights relevant words")
end

function suite.error_render_bad_line()
   local f, err = error.error("msg", {1, 3})
   local src = { source = "SOURCE", lines = { } }
   error.augment(err, src, 1)
   local estr = error.render(err)
   local line1, line2, line3, line4 = estr:match("^([^\n]*)\n([^\n]*)\n([^\n]*)\n([^\n]*)$")
   assert(line1, "There is a line 1")
   assert(line2, "There is a line 2")
   assert(line3, "There is a line 3")
   assert(line4, "There is a line 4")
   assert(line1 == "msg", "The first line should be the error message")
   assert(line2 == "SOURCE :: 1", "The second line is where the error happened")
   assert(line3 == "???", "The third line is the original line")
   assert(line4 == "^^^", "The fourth line highlights relevant words")
end

local count_ok = 0
for _, testname in ipairs(testnames) do
--   print("Run: " .. testname)
   local ok, err = xpcall(suite[testname], debug.traceback)
   if not ok then
      print(err)
      print()
   else
      count_ok = count_ok + 1
   end
end

print(tostring(count_ok) .. "/" .. tostring(#testnames) .. " [" .. tostring(total_asserts) .. "] OK")

os.exit(count_ok == #testnames and 0 or 1)
