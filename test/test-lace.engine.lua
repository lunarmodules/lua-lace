-- test/test-lace.engine.lua
--
-- Lua Access Control Engine -- Tests for the ruleset runtime engine
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For Licence terms, see COPYING
--

-- Step one, start coverage

local luacov = require 'luacov'

local lace = require 'lace'

local testnames = {}

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

function suite.check_empty_ruleset_fails()
   local compctx = {[".lace"]={}}
   local ruleset, msg = lace.compiler.compile(compctx, "src", "")
   assert(type(ruleset) == "table", "Could not compile empty ruleset")
   local execctx = {}
   local result, msg = lace.engine.run(ruleset, execctx)
   assert(result == false, "Empty failure returns false")
end

function suite.check_bad_exec_fn_returns_nil()
   local function _explode()
      return { fn = function() error("EXPLODE") end, args = {} }
   end
   local compctx = {[".lace"]={commands={explode=_explode}}}
   local ruleset, msg = lace.compiler.compile(compctx, "src", "explode")
   assert(type(ruleset) == "table", "Could not compile exploding ruleset")
   local execctx = {}
   local result, msg = lace.engine.run(ruleset, execctx)
   assert(result == nil, "Lua failures should return nil")
   assert(msg:match("EXPLODE"), "Expected explosion not detected")
end

function suite.check_error_propagates()
   local function _explode()
      return { fn = function() return false, "EXPLODE" end, args = {} }
   end
   local compctx = {[".lace"]={commands={explode=_explode}}}
   local ruleset, msg = lace.compiler.compile(compctx, "src", "explode")
   assert(type(ruleset) == "table", "Could not compile exploding ruleset")
   local execctx = {}
   local result, msg = lace.engine.run(ruleset, execctx)
   assert(result == false, "Internal failures should return false")
   assert(msg:match("EXPLODE"), "Expected explosion not detected")
end

function suite.check_deny_works()
   local compctx = {[".lace"]={}}
   local ruleset, msg = lace.compiler.compile(compctx, "src", "deny everything")
   assert(type(ruleset) == "table", "Could not compile exploding ruleset")
   local execctx = {}
   local result, msg = lace.engine.run(ruleset, execctx)
   assert(result == "deny", "Denial not returned")
   assert(msg:match("everything"), "Expected reason not detected")
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

print("Engine: " .. tostring(count_ok) .. "/" .. tostring(#testnames) .. " OK")

os.exit(count_ok == #testnames and 0 or 1)
