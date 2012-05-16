-- lib/lace.lua
--
-- Lua Access Control Engine
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For licence terms, see COPYING
--

local lex = require "lace.lex"
local compiler = require "lace.compiler"
local builtin = require "lace.builtin"
local engine = require "lace.engine"

local _VERSION = 0

local VERSION = "Lace Version " .. tostring(_VERSION)

return {
   lex = lex,
   compiler = compiler,
   builtin = builtin,
   engine = engine,
   _VERSION = _VERSION,
   VERSION = VERSION,
}
