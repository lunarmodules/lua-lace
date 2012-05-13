-- test/test-lex.lua
--
-- Lua Access Control Engine -- Tests for the lexer
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For Licence terms, see COPYING
--

-- Step one, start coverage

local luacov = require 'luacov'

local lex = require 'lace.lex'

local testnames = {}

local function add_test(suite, name, value)
   rawset(suite, name, value)
   testnames[#testnames+1] = name
end

local suite = setmetatable({}, {__newindex = add_test})

function suite.empty_string()
   local content = assert(lex.string("", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines), "Lines is not a table")
   assert(#content.lines == 0, "There are lines provided, despite source being empty")
end

function suite.single_cmd_string()
   local content = assert(lex.string("hello", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines), "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(#content.lines[1].content == 1, "The line should have 1 word")
   assert(content.lines[1].content[1].pos == 1, "The word starts at the first character")
   assert(content.lines[1].content[1].str == "hello", "The word is 'hello'")
end

function suite.single_cmd_two_words_string()
   local content = assert(lex.string("hello world", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines), "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(#content.lines[1].content == 2, "The line should have 2 words")
   assert(content.lines[1].content[1].pos == 1, "The word starts at the first character")
   assert(content.lines[1].content[1].str == "hello", "The word is 'hello'")
   assert(content.lines[1].content[2].pos == 7, "The word starts at the seventh character")
   assert(content.lines[1].content[2].str == "world", "The word is 'world'")
end

function suite.two_cmds_two_words_string()
   local content = assert(lex.string("hello world\nworld hello", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines), "Lines is not a table")
   assert(#content.lines == 2, "There should have been two lines")
   assert(#content.lines[1].content == 2, "The line should have 2 words")
   assert(content.lines[1].content[1].pos == 1, "The word starts at the first character")
   assert(content.lines[1].content[1].str == "hello", "The word starts is 'hello'")
   assert(content.lines[1].content[2].pos == 7, "The word starts at the seventh character")
   assert(content.lines[1].content[2].str == "world", "The word is 'hello'")
   assert(#content.lines[2].content == 2, "The line should have 2 words")
   assert(content.lines[2].content[1].pos == 1, "The word starts at the first character")
   assert(content.lines[2].content[1].str == "world", "The word is 'word'")
   assert(content.lines[2].content[2].pos == 7, "The word starts at the seventh character")
   assert(content.lines[2].content[2].str == "hello", "The word is 'hello'")
end

function suite.one_hash_comment()
   local content = assert(lex.string("# Hello", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines), "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(content.lines[1].type == "comment", "The line should be a comment")
end

function suite.one_slashes_comment()
   local content = assert(lex.string("// Hello", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines), "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(content.lines[1].type == "comment", "The line should be a comment")
end

function suite.one_dashes_comment()
   local content = assert(lex.string("-- Hello", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines), "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(content.lines[1].type == "comment", "The line should be a comment")
end

function suite.pure_whitespace()
   local content = assert(lex.string(" ", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines), "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(content.lines[1].type == "whitespace", "The line should be whitespace")
end

function suite.whitespace_then_comment()
   local content = assert(lex.string(" -- Fish", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines), "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(content.lines[1].type == "comment", "The line should be whitespace")
end

function suite.whitespace_then_command()
   local content = assert(lex.string("   hello", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines), "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(#content.lines[1].content == 1, "The line should have 1 word")
   assert(content.lines[1].content[1].pos == 4, "The word starts at the fourth character")
   assert(content.lines[1].content[1].str == "hello", "The word is 'hello'")
end

function suite.whitespace_in_command()
   local content = assert(lex.string("hello   world", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines), "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(#content.lines[1].content == 2, "The line should have 2 words")
   assert(content.lines[1].content[1].pos == 1, "The word starts at the first character")
   assert(content.lines[1].content[1].str == "hello", "The word is 'hello'")
   assert(content.lines[1].content[2].pos == 9, "The word starts at the ninth character")
   assert(content.lines[1].content[2].str == "world", "The word is 'world'")
end

local count_ok = 0
for _, testname in ipairs(testnames) do
   print("Run: " .. testname)
   local ok, err = xpcall(suite[testname], debug.traceback)
   if not ok then
      print(err)
      print()
   else
      count_ok = count_ok + 1
   end
end

print("Lex: " .. tostring(count_ok) .. "/" .. tostring(#testnames) .. " OK")

os.exit(count_ok == #testnames and 0 or 1)
