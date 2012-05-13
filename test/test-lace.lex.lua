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

local suite = {}

function suite.test_01_empty_string()
end

local testnames = {}
for k in pairs(suite) do
   testnames[#testnames+1] = k
end
table.sort(testnames)

local count_ok = 0
for _, testname in ipairs(testnames) do
   local ok, err = xpcall(suite[testname], debug.traceback)
   if not ok then
      print(testname .. ":")
      print(err)
      print()
   else
      count_ok = count_ok + 1
   end
end

print("Lex: " .. tostring(count_ok) .. "/" .. tostring(#testnames) .. " OK")
