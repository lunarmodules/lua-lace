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

function suite.builtin_get_set_unconditional()
   builtin.get_set_last_unconditional_result("FOO")
   assert(builtin.get_set_last_unconditional_result() == "FOO",
	  "Result not saved")
end

function suite.builtin_get_set_last()
   builtin.get_set_last_result("FOO")
   assert(builtin.get_set_last_result() == "FOO",
	  "Result not saved")
end

function suite.run_builtin_allow_deny_unconditional_saved()
   builtin.get_set_last_unconditional_result()

   local cmdtab, msg = builtin.commands.allow({}, "allow", "because")
   assert(type(cmdtab) == "table", "Result should be a table")
   assert(type(cmdtab.fn) == "function", "Result should contain a function")
   assert(type(cmdtab.args) == "table", "Result table should contain an args table")
   local result, msg = cmdtab.fn({}, unpack(cmdtab.args))
   assert(result == "allow", "Expected result should be 'allow'")
   assert(msg == "because", "Expected reason should be 'because'")

   local last = builtin.get_set_last_unconditional_result()
   assert(last == "allow", "The last unconditional result was not allow?")
end

function suite.run_builtin_allow_deny_conditional_saved()
   builtin.get_set_last_result()

   local cmdtab, msg = builtin.commands.allow({}, "allow", "because", "fishes")
   assert(type(cmdtab) == "table", "Result should be a table")
   assert(type(cmdtab.fn) == "function", "Result should contain a function")
   assert(type(cmdtab.args) == "table", "Result table should contain an args table")

   local last = builtin.get_set_last_result()
   assert(last == "allow", "The last conditional result was not allow?")
end

function suite.compile_builtin_default_noresult()
   local compctx = {[".lace"] = {}}
   local cmdtab, msg = builtin.commands.default(compctx, "default")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("Expected result"), "Expected error should mention a lack of result")
end

function suite.compile_builtin_default_resultbad()
   local compctx = {[".lace"] = {}}
   local cmdtab, msg = builtin.commands.default(compctx, "default", "FISH")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("allow or deny"), "Expected error should mention a bad of result")
end

function suite.compile_builtin_default_extra_fluff()
   local compctx = {[".lace"] = {}}
   local cmdtab, msg = builtin.commands.default(compctx, "default", "allow", "", "unwanted")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("additional"), "Expected error should mention additional content")
end

function suite.compile_builtin_default_ok()
   local compctx = {[".lace"] = {}}
   local cmdtab, msg = builtin.commands.default(compctx, "default", "allow", "because")
   assert(type(cmdtab) == "table", "Successful compilation should return a table")
   assert(type(cmdtab.fn) == "function", "With a function")
   assert(type(cmdtab.args) == "table", "And an arg table")
   assert(cmdtab.fn() == true, "Default command should always return true")
   assert(type(compctx[".lace"].default) == "table", "Default should always set up the context")
   assert(type(compctx[".lace"].default.fn) == "function", "Default table should have a function like a rule")
end

function suite.compile_builtin_default_twice()
   local compctx = {[".lace"] = {}}
   local cmdtab, msg = builtin.commands.default(compctx, "default", "allow", "")
   assert(type(cmdtab) == "table", "Successful compilation should return a table")
   local cmdtab, msg = builtin.commands.default(compctx, "default", "allow", "")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("change the"), "Expected error should mention changing the default")
end

function suite.compile_builtin_default_noreason()
   local compctx = {[".lace"] = {}}
   local cmdtab, msg = builtin.commands.default(compctx, "default", "allow")
   assert(type(cmdtab) == "table", "Successful compilation should return a table")
   assert(type(cmdtab.fn) == "function", "With a function")
   assert(type(cmdtab.args) == "table", "And an arg table")
   assert(cmdtab.fn() == true, "Default command should always return true")
   assert(type(compctx[".lace"].default) == "table", "Default should always set up the context")
   assert(type(compctx[".lace"].default.fn) == "function", "Default table should have a function like a rule")
end

function suite.compile_builtin_define_noname()
   local compctx = {[".lace"] = {}}
   local cmdtab, msg = builtin.commands.define(compctx, "define")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("Expected name"), "Expected error should mention a lack of name")
end

function suite.compile_builtin_define_badname()
   local compctx = {[".lace"] = {}}
   local cmdtab, msg = builtin.commands.define(compctx, "define", "!fish")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("Bad name"), "Expected error should mention a bad name")
end

function suite.compile_builtin_define_noctype()
   local compctx = {[".lace"] = {}}
   local cmdtab, msg = builtin.commands.define(compctx, "define", "fish")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("Expected control"), "Expected error should mention a lack of control type")
end

function suite.compile_builtin_define_badctype()
   local compctx = {[".lace"] = {}}
   local cmdtab, msg = builtin.commands.define(compctx, "define", "fish", "fish")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("Unknown control"), "Expected error should mention unknown control type")
end

function suite.compile_builtin_define_ctype_errors()
   local function _fish()
      return false, { msg = "Argh" }
   end
   local compctx = {[".lace"] = { controltype = { fish = _fish }}}
   local cmdtab, msg = builtin.commands.define(compctx, "define", "fish", "fish")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("Argh"), "Expected error should be passed through")
end

function suite.compile_builtin_define_ctype_errors_offset()
   local function _fish()
      return false, { msg = "Argh", words = {0} }
   end
   local compctx = {[".lace"] = { controltype = { fish = _fish }}}
   local cmdtab, msg = builtin.commands.define(compctx, "define", "fish", "fish")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("Argh"), "Expected error should be passed through")
   assert(msg.words[1] == 2, "Error words should be offset by 2")
end

function suite.compile_builtin_define_ok()
   local function _fish()
      return {
	 JEFF = true
      }
   end
   local compctx = {[".lace"] = { controltype = { fish = _fish }}}
   local cmdtab, msg = builtin.commands.define(compctx, "define", "fish", "fish")
   assert(type(cmdtab) == "table", "Successful compilation returns tables")
   assert(type(cmdtab.fn) == "function", "With functions")
   local ectx = {}
   local ok, msg = cmdtab.fn(ectx, unpack(cmdtab.args))
   assert(ok, "Running a define should work")
   assert(ectx[".lace"].defs.fish.JEFF, "definition should have passed through")
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
