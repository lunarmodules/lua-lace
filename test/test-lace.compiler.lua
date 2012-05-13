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
local sio = require 'luxio.simple'

local testnames = {}

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
   assert(msg:match("context must contain"), "Supposed to whinge about context missing .lace")
end

function suite.context_dot_lace_not_table()
   local result, msg = compiler.compile({[".lace"] = true}, "")
   assert(result == nil, "Lua errors should return nil")
   assert(msg:match("context must contain"), "Supposed to whinge about context missing .lace")
end

function suite.source_not_string()
   local result, msg = compiler.compile({[".lace"] = {}}, false)
   assert(result == nil, "Lua errors should return nil")
   assert(msg:match("name must be a string"), "Supposed to whinge about name not being a string")
end

function suite.content_not_string()
   local result, msg = compiler.compile({[".lace"] = {}}, "", false)
   assert(result == nil, "Lua errors should return nil")
   assert(msg:match("must be nil or a string"), "Supposed to whinge about content not being a string but being non-nil")
end

function suite.empty_content_no_loader()
   local result, msg = compiler.compile({[".lace"] = {}}, "", "")
   assert(type(result) == "table", "No ruleset returned?")
end

function suite.no_content_no_loader()
   local result, msg = compiler.compile({[".lace"] = {}}, "")
   assert(result == false, "Internal errors should return false")
   assert(msg:match("Ruleset not found:"), "Supposed to whinge about ruleset not being found")
end

-- Now we set up a more useful context and use that going forward:

local comp_context = {
   [".lace"] = {
      loader = function(ctx, name)
		  if name == "THROW_ERROR" then
		     error("THROWN")
		  end
		  local fh, msg = sio.open("test/test-lace.compile-" .. name .. ".rules", "r")
		  if not fh then
		     return compiler.error("LOADER: Unknown: " .. name, {1})
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
   assert(type(result) == "table", "Loading a ruleset should result in a table")
   assert(#result.rules == 0, "There should be no rules present")
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

print("Compiler: " .. tostring(count_ok) .. "/" .. tostring(#testnames) .. " OK")

os.exit(count_ok == #testnames and 0 or 1)
