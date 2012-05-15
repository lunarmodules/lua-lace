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
   assert(type(content.lines) == "table", "Lines is not a table")
   assert(#content.lines == 0, "There are lines provided, despite source being empty")
end

function suite.single_cmd_string()
   local content = assert(lex.string("hello", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines) == "table", "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(#content.lines[1].content == 1, "The line should have 1 word")
   assert(content.lines[1].content[1].spos == 1, "The word starts at the first character")
   assert(content.lines[1].content[1].epos == 5, "The word ends at the fifth character")
   assert(content.lines[1].content[1].str == "hello", "The word is 'hello'")
   assert(type(content.lines[1].warnings) == "nil", "There should be no warnings")
end

function suite.single_cmd_two_words_string()
   local content = assert(lex.string("hello world", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines) == "table", "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(#content.lines[1].content == 2, "The line should have 2 words")
   assert(content.lines[1].content[1].spos == 1, "The word starts at the first character")
   assert(content.lines[1].content[1].epos == 5, "The word ends at the fifth character")
   assert(content.lines[1].content[1].str == "hello", "The word is 'hello'")
   assert(content.lines[1].content[2].spos == 7, "The word starts at the seventh character")
   assert(content.lines[1].content[2].epos == 11, "The word ends at the eleventh character")
   assert(content.lines[1].content[2].str == "world", "The word is 'world'")
end

function suite.two_cmds_two_words_string()
   local content = assert(lex.string("hello world\nworld hello", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines) == "table", "Lines is not a table")
   assert(#content.lines == 2, "There should have been two lines")
   assert(#content.lines[1].content == 2, "The line should have 2 words")
   assert(content.lines[1].content[1].spos == 1, "The word starts at the first character")
   assert(content.lines[1].content[1].str == "hello", "The word starts is 'hello'")
   assert(content.lines[1].content[2].spos == 7, "The word starts at the seventh character")
   assert(content.lines[1].content[2].epos == 11, "The word ends at the eleventh character")
   assert(content.lines[1].content[2].str == "world", "The word is 'hello'")
   assert(#content.lines[2].content == 2, "The line should have 2 words")
   assert(content.lines[2].content[1].spos == 1, "The word starts at the first character")
   assert(content.lines[2].content[1].str == "world", "The word is 'word'")
   assert(content.lines[2].content[2].spos == 7, "The word starts at the seventh character")
   assert(content.lines[2].content[2].epos == 11, "The word ends at the eleventh character")
   assert(content.lines[2].content[2].str == "hello", "The word is 'hello'")
end

function suite.one_hash_comment()
   local content = assert(lex.string("# Hello", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines) == "table", "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(content.lines[1].type == "comment", "The line should be a comment")
end

function suite.one_slashes_comment()
   local content = assert(lex.string("// Hello", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines) == "table", "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(content.lines[1].type == "comment", "The line should be a comment")
end

function suite.one_dashes_comment()
   local content = assert(lex.string("-- Hello", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines) == "table", "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(content.lines[1].type == "comment", "The line should be a comment")
end

function suite.pure_whitespace()
   local content = assert(lex.string(" ", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines) == "table", "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(content.lines[1].type == "whitespace", "The line should be whitespace")
end

function suite.whitespace_then_comment()
   local content = assert(lex.string(" -- Fish", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines) == "table", "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(content.lines[1].type == "comment", "The line should be whitespace")
end

function suite.whitespace_then_command()
   local content = assert(lex.string("   hello", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines) == "table", "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(#content.lines[1].content == 1, "The line should have 1 word")
   assert(content.lines[1].content[1].spos == 4, "The word starts at the fourth character")
   assert(content.lines[1].content[1].epos == 8, "The word ends at the ninth character")
   assert(content.lines[1].content[1].str == "hello", "The word is 'hello'")
end

function suite.whitespace_in_command()
   local content = assert(lex.string("hello   world", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines) == "table", "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(#content.lines[1].content == 2, "The line should have 2 words")
   assert(content.lines[1].content[1].spos == 1, "The word starts at the first character")
   assert(content.lines[1].content[1].str == "hello", "The word is 'hello'")
   assert(content.lines[1].content[2].spos == 9, "The word starts at the ninth character")
   assert(content.lines[1].content[2].str == "world", "The word is 'world'")
end

function suite.single_quoted_word()
   local content = assert(lex.string("'hello'", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines) == "table", "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(#content.lines[1].content == 1, "The line should have 1 word")
   assert(content.lines[1].content[1].spos == 1, "The word starts at the first character")
   assert(content.lines[1].content[1].epos == 7, "The word ends at the seventh character")
   assert(content.lines[1].content[1].str == "hello", "The word is 'hello'")
end

function suite.double_quoted_word()
   local content = assert(lex.string('"hello"', "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines) == "table", "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(#content.lines[1].content == 1, "The line should have 1 word")
   assert(content.lines[1].content[1].spos == 1, "The word starts at the first character")
   assert(content.lines[1].content[1].str == "hello", "The word is 'hello'")
end

function suite.escape_outside_quotes()
   local content = assert(lex.string("\\this", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines) == "table", "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(#content.lines[1].content == 1, "The line should have 1 word")
   assert(content.lines[1].content[1].spos == 1, "The word starts at the first character")
   assert(content.lines[1].content[1].str == "this", "The word is 'this'")
end

function suite.escape_inside_normal()
   local content = assert(lex.string("'hell\\o'", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines) == "table", "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(#content.lines[1].content == 1, "The line should have 1 word")
   assert(content.lines[1].content[1].spos == 1, "The word starts at the first character")
   assert(content.lines[1].content[1].str == "hello", "The word is 'hello'")
end

function suite.escape_inside_quotetype()
   local content = assert(lex.string("'hello\\''", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines) == "table", "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(#content.lines[1].content == 1, "The line should have 1 word")
   assert(content.lines[1].content[1].spos == 1, "The word starts at the first character")
   assert(content.lines[1].content[1].str == "hello'", "The word is \"hello'\"")
end

function suite.escape_inside_tab()
   local content = assert(lex.string("'hello\\t'", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines) == "table", "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(#content.lines[1].content == 1, "The line should have 1 word")
   assert(content.lines[1].content[1].spos == 1, "The word starts at the first character")
   assert(content.lines[1].content[1].str == "hello\t", "The word is \"hello\\t\"")
end

function suite.escape_inside_newline()
   local content = assert(lex.string("'hello\\n'", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines) == "table", "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(#content.lines[1].content == 1, "The line should have 1 word")
   assert(content.lines[1].content[1].spos == 1, "The word starts at the first character")
   assert(content.lines[1].content[1].str == "hello\n", "The word is \"hello\\n\"")
end

function suite.escape_outside_unused()
   local content = assert(lex.string("hello\\", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines) == "table", "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(#content.lines[1].content == 1, "The line should have 1 word")
   assert(content.lines[1].content[1].spos == 1, "The word starts at the first character")
   assert(content.lines[1].content[1].str == "hello", "The word is \"hello\"")
   assert(type(content.lines[1].warnings) == "table", "There should be a warning")
   assert(#content.lines[1].warnings == 1, "There should be one warning")
   assert(content.lines[1].warnings[1]:find("escape"), "The warning should be about the escape")
end

function suite.unclosed_quote()
   local content = assert(lex.string("'hello", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines) == "table", "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(#content.lines[1].content == 1, "The line should have 1 word")
   assert(content.lines[1].content[1].spos == 1, "The word starts at the first character")
   assert(content.lines[1].content[1].str == "hello", "The word is \"hello\"")
   assert(type(content.lines[1].warnings) == "table", "There should be a warning")
   assert(#content.lines[1].warnings == 1, "There should be one warning")
   assert(content.lines[1].warnings[1]:find("quoted"), "The warning should be about the unclosed quotes")
end

function suite.escape_inside_unclosed_unused()
   local content = assert(lex.string("'hello\\", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines) == "table", "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(#content.lines[1].content == 1, "The line should have 1 word")
   assert(content.lines[1].content[1].spos == 1, "The word starts at the first character")
   assert(content.lines[1].content[1].str == "hello", "The word is \"hello\"")
   assert(type(content.lines[1].warnings) == "table", "There should be a warning")
   assert(#content.lines[1].warnings == 2, "There should be two warnings")
   assert(content.lines[1].warnings[1]:find("quoted"), "The warning should be about the unclosed quotes")
   assert(content.lines[1].warnings[2]:find("escape"), "The warning should be about the escape")
end

function suite.empty_string_words_work()
   local content = assert(lex.string("allow ''", "SRC"))
   assert(content.source == "SRC", "Source name not propagated")
   assert(type(content.lines) == "table", "Lines is not a table")
   assert(#content.lines == 1, "There should have been one line")
   assert(#content.lines[1].content == 2, "The line should have 2 words")
   assert(content.lines[1].content[1].spos == 1, "The first word starts at the first character")
   assert(content.lines[1].content[1].str == "allow", "The word is \"allow\"")
   assert(content.lines[1].content[2].str == "", "The second word is empty")
   assert(content.lines[1].content[2].spos == 7, "The empty word starts at the seventh character")
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

print(tostring(count_ok) .. "/" .. tostring(#testnames) .. " OK")

os.exit(count_ok == #testnames and 0 or 1)
