-- test/test-lace.engine.lua
--
-- Lua Access Control Engine -- Tests for the ruleset runtime engine
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For Licence terms, see COPYING
--

-- Step one, start coverage

pcall(require, 'luacov')

local lace = require 'lace'

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

function suite.check_can_define_something()
   local ctx = {}
   local result, msg = lace.engine.define(ctx, "this", "that")
   assert(result == true, "Couldn't define something")
end

function suite.check_cannot_redefine_something()
   local ctx = {}
   local result, msg = lace.engine.define(ctx, "this", "that")
   assert(result == true, "Couldn't define something")
   local result, msg = lace.engine.define(ctx, "this", "that")
   assert(result == false, "Should not have been able to redefine this")
   assert(type(msg) == "table", "Internal errors should be tables")
   assert(type(msg.msg) == "string", "Internal errors should have message strings")
   assert(msg.msg:match("to redefine"), "Error didn't mention redefinition")
end

function suite.check_cannot_test_unknown_values()
   local ctx = {}
   local result, msg = lace.engine.test(ctx, "this")
   assert(result == nil, "Internal errors should return nil")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have message strings")
   assert(msg.msg:match("nknown definition"), "Error did not mention unknown definitions")
end

function suite.check_can_test_known_functions()
   local ctx = {}
   local function run_test(ctx, arg)
      assert(arg == "FISH", "Argument not passed properly")
      ctx.ran = true
      return "fish", "blah"
   end
   local result, msg = lace.engine.define(ctx, "this", { fn = run_test, args = { "FISH" } })
   assert(result == true, "Could not make definition?")
   local result, msg = lace.engine.test(ctx, "this")
   assert(result == "fish", "Expected result was not returned")
   assert(msg == "blah", "Expected message was not returned")
   assert(ctx.ran, "Context was not passed properly")
end

function suite.check_bad_exec_fn_returns_nil()
   local function _explode()
      return { fn = function() error("EXPLODE") end, args = {} }
   end
   local compctx = {_lace={commands={explode=_explode}}}
   local ruleset, msg = lace.compiler.compile(compctx, "src", "explode\nallow because")
   assert(type(ruleset) == "table", "Could not compile exploding ruleset")
   local execctx = {}
   local result, msg = lace.engine.run(ruleset, execctx)
   assert(result == nil, "Lua failures should return nil")
   assert(msg:match("EXPLODE"), "Expected explosion not detected")
end

function suite.check_error_propagates()
   local function _explode()
      return { fn = function() return lace.error.error("EXPLODE", {1}) end, args = {} }
   end
   local compctx = {_lace={commands={explode=_explode}}}
   local ruleset, msg = lace.compiler.compile(compctx, "src", "explode\nallow because")
   assert(type(ruleset) == "table", "Could not compile exploding ruleset")
   local execctx = {}
   local result, msg = lace.engine.run(ruleset, execctx)
   assert(result == false, "Internal failures should return false")
   assert(msg:match("EXPLODE"), "Expected explosion not detected")
end

function suite.check_deny_works()
   local compctx = {_lace={}}
   local ruleset, msg = lace.compiler.compile(compctx, "src", "deny everything")
   assert(type(ruleset) == "table", "Could not compile exploding ruleset")
   local execctx = {}
   local result, msg = lace.engine.run(ruleset, execctx)
   assert(result == "deny", "Denial not returned")
   assert(msg:match("everything"), "Expected reason not detected")
end

-- More complete engine tests from here

local comp_context = {
   _lace = {
      loader = function(ctx, name)
		  if name == "THROW_ERROR" then
		     error("THROWN")
		  end
		  local fh = io.open("test/test-lace.engine-" .. name .. ".rules", "r")
		  if not fh then
		     return lace.error.error("LOADER: Unknown: " .. name, {1})
		  end
		  local content = fh:read("*a")
		  fh:close()
		  return "real-" .. name, content
	       end,
      commands = {
      },
      controltype = {
	 equal = function(ctx, eq, key, value)
		    return {
		       fn = function(ectx, ekey, evalue)
			       return ectx[ekey] == evalue
			    end,
		       args = { key, value },
		    }
		 end,
	 error = function(ctx, err)
		    return {
		       fn = function(ectx)
			       if ectx.error then
				  return nil, { msg = "woah", words = {1} }
			       end
			       return false
			    end,
		       args = {},
		    }
		 end,
      },
   },
}

function suite.test_plainallow_works()
   local ruleset, msg = lace.compiler.compile(comp_context, "plainallow")
   assert(type(ruleset) == "table", "Ruleset did not compile")
   local ectx = {}
   local result, msg = lace.engine.run(ruleset, ectx)
   assert(result == "allow", "Should allow")
   assert(msg == "because", "Because")
end

function suite.test_allow_with_define_works()
   local ruleset, msg = lace.compiler.compile(comp_context, "allowwithdefine")
   assert(type(ruleset) == "table", "Ruleset did not compile")
   local ectx = {}
   local result, msg = lace.engine.run(ruleset, ectx)
   assert(result == "allow", "Should allow")
   assert(msg == "because", "Because")
end

function suite.test_allow_with_define_used_works()
   local ruleset, msg = lace.compiler.compile(comp_context, "allowwithdefineused")
   assert(type(ruleset) == "table", "Ruleset did not compile")
   local ectx = {}
   local result, msg = lace.engine.run(ruleset, ectx)
   assert(result == "deny", "Should deny")
   assert(msg == "Default behaviour", "Because allow failed")
end

function suite.test_allow_with_define_used_works_and_passes()
   local ruleset, msg = lace.compiler.compile(comp_context, "allowwithdefineused")
   assert(type(ruleset) == "table", "Ruleset did not compile")
   local ectx = {this="that"}
   local result, msg = lace.engine.run(ruleset, ectx)
   assert(result == "allow", "Should allow")
   assert(msg == "because", "Because")
end

function suite.test_complex_ruleset()
   local ruleset, msg = lace.compiler.compile(comp_context, "complexruleset")
   assert(type(ruleset) == "table", "Ruleset did not compile")
   for _, s in ipairs{"one","two","three","four"} do
      local expect = (s == "one" or s == "two") and "allow" or "deny"
      local ectx = {state=s}
      local result, msg = lace.engine.run(ruleset, ectx)
      assert(result == expect, "Expected " .. expect)
      assert(msg == s, "Reason expected " .. s)
   end
end

function suite.test_runtime_error()
   local ruleset, msg = lace.compiler.compile(comp_context, "runtimeerror")
   assert(type(ruleset) == "table", "Ruleset did not compile")
   local ectx = {error=true}
   local result, msg = lace.engine.run(ruleset, ectx)
   assert(result == false, "Did not error out")
   assert(type(msg) == "string", "Generated a non-string error")
   assert(msg:find("woah"), "Did not generate the right error: " .. msg)
end

function suite.doubledefine()
   local ruleset, msg = lace.compiler.compile(comp_context, "doubledefine")
   assert(type(ruleset) == "table", "Ruleset did not compile")
   local ectx = {error = true}
   local result, msg = lace.engine.run(ruleset, ectx)
   assert(result == false, "Did not error out")
   local line1, line2, line3, line4 = msg:match("^([^\n]*)\n([^\n]*)\n([^\n]*)\n([^\n]*)$")
   assert(line1:find("redefine fish"), "The first line must mention the error")
   assert(line2 == "real-doubledefine :: 5", "The second line is where the error happened")
   assert(line3 == "define fish equal state two", "The third line is the original line")
   assert(line4 == "       ^^^^                ", "The fourth line highlights relevant words")
end

function suite.subdefine_works()
   local ruleset, msg = lace.compiler.compile(comp_context, "subdefine-works")
   assert(type(ruleset) == "table", "Ruleset did not compile")
   local ectx = {jeff = "geoff"}
   local result, msg = lace.engine.run(ruleset, ectx)
   assert(result, msg)
end

function suite.inverted_subdefine_works()
   local ruleset, msg = lace.compiler.compile(comp_context, "inverted-subdefine-works")
   assert(type(ruleset) == "table", "Ruleset did not compile")
   local ectx = {jeff = "geoff"}
   local result, msg = lace.engine.run(ruleset, ectx)
   assert(result, msg)
end

function suite.subdefine_err_reported()
   local ruleset, msg = lace.compiler.compile(comp_context, "subdefine-error")
   assert(type(ruleset) == "table", "Ruleset did not compile")
   local ectx = {error = true}
   local result, msg = lace.engine.run(ruleset, ectx)
   assert(result == false, "Did not error out")
   local line1, line2, line3, line4 = msg:match("^([^\n]*)\n([^\n]*)\n([^\n]*)\n([^\n]*)$")
   assert(line1 == "woah", "The first line must mention the error")
   assert(line2 == "real-subdefine-error :: 2", "The second line is where the error happened")
   assert(line3 == 'allow "Yay" [error]', "The third line is the original line")
   assert(line4 == "             ^^^^^ ", "The fourth line highlights relevant words")
end

function suite.subsubdefine_works()
   local ruleset, msg = lace.compiler.compile(comp_context, "subsubdefine-works")
   assert(type(ruleset) == "table", "Ruleset did not compile")
   local ectx = {jeff = "geoff"}
   local result, msg = lace.engine.run(ruleset, ectx)
   assert(result, msg)
   assert(result == "allow", "Result should be allow")
   assert(msg == "PASS", "Message should be pass")
end

function suite.subsubdefine_err_reported()
   local ruleset, msg = lace.compiler.compile(comp_context, "subsubdefine-error")
   assert(type(ruleset) == "table", "Ruleset did not compile")
   local ectx = {error = true}
   local result, msg = lace.engine.run(ruleset, ectx)
   assert(result == false, "Did not error out")
   local line1, line2, line3, line4 = msg:match("^([^\n]*)\n([^\n]*)\n([^\n]*)\n([^\n]*)$")
   assert(line1 == "woah", "The first line must mention the error")
   assert(line2 == "real-subsubdefine-error :: 1", "The second line is where the error happened")
   assert(line3 == 'allow "FAIL" [anyof [equal jeff banana] [error]]', "The third line is the original line")
   assert(line4 == "                                         ^^^^^  ", "The fourth line highlights relevant words")
end

function suite.subdefine_chained_err_reported()
   local ruleset, msg = lace.compiler.compile(comp_context, "chaindefine-error")
   assert(type(ruleset) == "table", "Ruleset did not compile")
   local ectx = {error = true}
   local result, msg = lace.engine.run(ruleset, ectx)
   assert(result == false, "Did not error out")
   local lines = {}
   msg:gsub("([^\n]*)\n?", function(c) table.insert(lines, c) end)
   assert(lines[1] == "woah", "The first line must mention the error")
   assert(lines[2] == "real-chaindefine-error :: 2", "The second line is where the error happened")
   assert(lines[3] == 'allow "FAIL" [anyof [equal jeff banana] bogus]', "The third line is the original line")
   assert(lines[4] == "                                        ^^^^^ ", "The fourth line highlights relevant words")
   assert(lines[5] == "real-chaindefine-error :: 1", "The fifth line is where the definition that errored comes from")
   assert(lines[6] == 'define bogus error', "The sixth line is the define")
   assert(lines[7] == "             ^^^^^", "The seventh line highlights relevant words")
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
