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
-- The Lua Access Control Engine library consists primarily of a ruleset
-- compiler and execution engine.  In addition there is a lexer and also a
-- complex error reporting system designed to ensure application authors who
-- use Lace in their projects can provide good error messages to their users.
--
-- * For compiling rulesets, see `lace.compiler.compile`.
-- * For running compiled rulesets, see `lace.engine.run`.

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
