-- test/test-lace.builtin.lua
--
-- Lua Access Control Engine -- Tests for the builtins for Lace
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For Licence terms, see COPYING
--

-- Step one, start coverage

local luacov = require 'luacov'

local builtin = require 'lace.builtin'

local testnames = {}

local function add_test(suite, name, value)
   rawset(suite, name, value)
   testnames[#testnames+1] = name
end

local suite = setmetatable({}, {__newindex = add_test})

function suite.compile_builtin_allow_deny_badname()
   local cmdtab, msg = builtin.commands.allow({}, "badname")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("badname"), "Expected error should contain badname")
   assert(type(msg.words) == "table", "Internal error should contain a words table")
   assert(msg.words[1] == 1, "Internal error should reference word 1, the bad command name")
end

function suite.compile_builtin_allow_deny_noreason()
   local cmdtab, msg = builtin.commands.allow({}, "allow")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("Expected reason"), "Expected error should mention a lack of reason")
end

function suite.compile_builtin_allow_deny_novariables()
   local cmdtab, msg = builtin.commands.allow({}, "allow", "because")
   assert(type(cmdtab) == "table", "Result should be a table")
   assert(type(cmdtab.fn) == "function", "Result should contain a function")
   assert(type(cmdtab.args) == "table", "Result table should contain an args table")
   assert(cmdtab.args[1] == "allow", "Result args table should contain the given result 'allow'")
   assert(cmdtab.args[2] == "because", "Result args table should contain te given reason 'because'")
   assert(type(cmdtab.args[3]) == "table", "The third argument should be a table")
   assert(#cmdtab.args[3] == 0, "There should be no conditions")
end

function suite.run_builtin_allow_deny_novariables()
   local cmdtab, msg = builtin.commands.allow({}, "allow", "because")
   assert(type(cmdtab) == "table", "Result should be a table")
   assert(type(cmdtab.fn) == "function", "Result should contain a function")
   assert(type(cmdtab.args) == "table", "Result table should contain an args table")
   local result, msg = cmdtab.fn({}, unpack(cmdtab.args))
   assert(result == "allow", "Expected result should be 'allow'")
   assert(msg == "because", "Expected reason should be 'because'")
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

print("Builtin: " .. tostring(count_ok) .. "/" .. tostring(#testnames) .. " OK")

os.exit(count_ok == #testnames and 0 or 1)
