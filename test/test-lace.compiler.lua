-- test/test-compiler.lua
--
-- Lua Access Control Engine -- Tests for the compiler
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For Licence terms, see COPYING
--

-- Step one, start coverage

local luacov = require 'luacov'

local compiler = require 'lace.compiler'
local err = require 'lace.error'

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

function suite.context_missing()
   local result, msg = compiler.compile(nil, "")
   assert(result == nil, "Lua errors should return nil")
   assert(msg:match("context must be a table"), "Supposed to whinge about context not being a table")
end

function suite.context_missing_dot_lace()
   local result, msg = compiler.compile({}, "")
   assert(result == nil, "Lua errors should return nil")
   assert(msg:match("context must contain"), "Supposed to whinge about context missing _lace")
end

function suite.context_dot_lace_not_table()
   local result, msg = compiler.compile({_lace = true}, "")
   assert(result == nil, "Lua errors should return nil")
   assert(msg:match("context must contain"), "Supposed to whinge about context missing _lace")
end

function suite.source_not_string()
   local result, msg = compiler.compile({_lace = {}}, false)
   assert(result == nil, "Lua errors should return nil")
   assert(msg:match("name must be a string"), "Supposed to whinge about name not being a string")
end

function suite.content_not_string()
   local result, msg = compiler.compile({_lace = {}}, "", false)
   assert(result == nil, "Lua errors should return nil")
   assert(msg:match("must be nil or a string"), "Supposed to whinge about content not being a string but being non-nil")
end

function suite.empty_content_no_loader()
   local result, msg = compiler.compile({_lace = {}}, "", "")
   assert(result == false, "Internal errors should return false")
   assert(msg:match("whatsoever"), "Supposed to whinge about no allow/deny at all")
end

function suite.no_content_no_loader()
   local result, msg = compiler.compile({_lace = {}}, "")
   assert(result == false, "Internal errors should return false")
   assert(msg:match("Ruleset not found:"), "Supposed to whinge about ruleset not being found")
end

function suite.no_unconditional_action()
   local result, msg = compiler.compile({_lace = {}}, "", "deny stuff cond")
   assert(type(result) == "table", "Loading a ruleset should result in a table")
   assert(#result.rules == 2, "There should be two rules present")
   local rule = result.rules[1]
   assert(type(rule) == "table", "Rules should be tables")
   assert(type(rule.fn) == "function", "Rules should have functions")
   assert(type(rule.args) == "table", "Rules should have arguments")
   -- rule 2 should be an unconditional allow with 'Default behaviour' as the reason,
   -- let's check
   local r2a = result.rules[2].args
   assert(r2a[1] == "allow", "Rule 2 should be an allow")
   assert(r2a[2] == "Default behaviour", "Rule 2's reason should be 'Default behaviour'")
   assert(#r2a[3] == 0, "Rule 2 should have no conditions")
end

function suite.no_unconditional_action_default_deny()
   local result, msg = compiler.compile({_lace = {}}, "", "default deny\ndeny stuff cond")
   assert(type(result) == "table", "Loading a ruleset should result in a table")
   assert(#result.rules == 3, "There should be three rules present")
   local rule = result.rules[1]
   assert(type(rule) == "table", "Rules should be tables")
   assert(type(rule.fn) == "function", "Rules should have functions")
   assert(type(rule.args) == "table", "Rules should have arguments")
   -- rule 3 should be an unconditional deny with 'Default behaviour' as the reason,
   -- let's check
   local r3a = result.rules[3].args
   assert(r3a[1] == "deny", "Rule 3 should be a deny, despite last rule behind a deny")
   assert(r3a[2] == "Default behaviour", "Rule 3's reason should be 'Default behaviour'")
   assert(#r3a[3] == 0, "Rule 2 should have no conditions")
end

function suite.is_unconditional_action_default_deny()
   local result, msg = compiler.compile({_lace = {}}, "", "default deny\nallow stuff")
   assert(type(result) == "table", "Loading a ruleset should result in a table")
   assert(#result.rules == 2, "There should be two rules present")
   local rule = result.rules[1]
   assert(type(rule) == "table", "Rules should be tables")
   assert(type(rule.fn) == "function", "Rules should have functions")
   assert(type(rule.args) == "table", "Rules should have arguments")
   -- rule 2 should be an unconditional allow with 'stuff' as the reason
   -- let's check
   local r2a = result.rules[2].args
   assert(r2a[1] == "allow", "Rule 2 should be an allow, despite default being deny")
   assert(r2a[2] == "stuff", "Rule 2's reason should be 'stuff'")
   assert(#r2a[3] == 0, "Rule 2 should have no conditions")
end

-- Now we set up a more useful context and use that going forward:

local comp_context = {
   _lace = {
      loader = function(ctx, name)
		  if name == "THROW_ERROR" then
		     error("THROWN")
		  end
		  local fh = io.open("test/test-lace.compile-" .. name .. ".rules", "r")
		  if not fh then
		     return err.error("LOADER: Unknown: " .. name, {1})
		  end
		  local content = fh:read("*a")
		  fh:close()
		  return "real-" .. name, content
	       end,
      commands = {
	 DISABLEDCOMMAND = false,
      },
   },
}

function suite.loader_errors()
   local result, msg = compiler.compile(comp_context, "THROW_ERROR")
   assert(result == nil, "Lua errors should return nil")
   assert(msg:match("THROWN"), "Error returned didn't match what we threw")
end

function suite.load_no_file()
   local result, msg = compiler.compile(comp_context, "NOT_FOUND")
   assert(result == false, "Internal errors should return false")
   assert(msg:match("LOADER: Unknown: NOT_FOUND"), "Error returned didn't match what we returned from loader")
end

function suite.load_file_with_no_rules()
   local result, msg = compiler.compile(comp_context, "nothing")
   assert(result == false, "Internal errors should return false")
   assert(msg:match("whatsoever"), "Error returned didn't match expected whinge about no allow/deny")
end

function suite.load_file_with_bad_command()
   local result, msg = compiler.compile(comp_context, "badcommand")
   assert(result == false, "Internal errors should return false")
   assert(msg:match("BADCOMMAND"), "Error returned did not match the bad command")
end

function suite.load_file_with_disabled_command()
   local result, msg = compiler.compile(comp_context, "disabledcommand")
   assert(result == false, "Internal errors should return false")
   assert(msg:match("is disabled by"), "Error returned did not match the bad command")
end

function suite.load_file_with_bad_deny_command()
   local result, msg = compiler.compile(comp_context, "denynoreason")
   assert(result == false, "Internal errors should return false")
   assert(msg:match("got nothing"), "Error returned did not match expected behaviour from deny")
end

function suite.load_file_with_one_command()
   local result, msg = compiler.compile(comp_context, "denyall")
   assert(type(result) == "table", "Loading a ruleset should result in a table")
   assert(#result.rules == 1, "There should be one rule present")
   local rule = result.rules[1]
   assert(type(rule) == "table", "Rules should be tables")
   assert(type(rule.fn) == "function", "Rules should have functions")
   assert(type(rule.args) == "table", "Rules should have arguments")
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
