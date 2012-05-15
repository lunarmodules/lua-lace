-- test/test-lace.lua
--
-- Lua Access Control Engine -- Tests for the core Lace module
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For Licence terms, see COPYING
--

-- Step one, start coverage

local luacov = require 'luacov'

local lace = require 'lace'
local lex = require 'lace.lex'
local compiler = require 'lace.compiler'
local builtin = require 'lace.builtin'
local engine = require 'lace.engine'

local testnames = {}

local function add_test(suite, name, value)
   rawset(suite, name, value)
   testnames[#testnames+1] = name
end

local suite = setmetatable({}, {__newindex = add_test})

function suite.lex_passed()
   assert(lace.lex == lex, "Lace's lex entry is not lace.lex")
end

function suite.compiler_passed()
   assert(lace.compiler == compiler, "Lace's compiler entry is not lace.compiler")
end

function suite.builtin_passed()
   assert(lace.builtin == builtin, "Lace's builtin entry is not lace.builtin")
end

function suite.engine_passed()
   assert(lace.engine == engine, "Lace's engine entry is not lace.engine")
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
