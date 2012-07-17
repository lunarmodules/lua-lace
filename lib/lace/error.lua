-- lib/lace/error.lua
--
-- Lua Access Control Engine - Error management
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For licence terms, see COPYING
--

local function _error(str, words)
   return false, { msg = str, words = words or {} }
end

return {
   error = _error
}