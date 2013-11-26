-- lib/lace.lua
--
-- Lua Access Control Engine
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For licence terms, see COPYING
--

--- Lua Access Control Engine.
--
-- 

local lex = require "lace.lex"
local compiler = require "lace.compiler"
local builtin = require "lace.builtin"
local engine = require "lace.engine"
local error = require 'lace.error'

local _VERSION = 1
local _ABI = 1

local VERSION = "Lace Version " .. tostring(_VERSION)

return {
   lex = lex,
   compiler = compiler,
   builtin = builtin,
   engine = engine,
   error = error,
   _VERSION = _VERSION,
   VERSION = VERSION,
   _ABI = _ABI,
   ABI = ABI,
}
