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

return {
   lex = lex,
   compiler = compiler,
   builtin = builtin,
}