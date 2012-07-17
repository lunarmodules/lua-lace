-- test/test-lace.lua
--
-- Lua Access Control Engine -- Tests for the Lace error module
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For Licence terms, see COPYING
--

-- Step one, start coverage

local luacov = require 'luacov'

local error = require 'lace.error'

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

function suite.error_formation()
   local words = {}
   local ret1, ret2 = error.error("msg", words)
   assert(ret1 == false, "First return of error() should be false")
   assert(type(ret2) == "table", "Second return of error() should be a table")
   assert(ret2.msg == "msg", "Message should be passed through")
   assert(ret2.words == words, "Words should be passed through")
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
