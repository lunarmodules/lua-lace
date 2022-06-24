package = "lua-lace"
version = "dev-1"
source = {
   url = "git+https://github.com/lunarmodules/lua-lace.git"
}
description = {
   summary = "Lace is a simple access control engine modelled on Squid's acl syntax.",
   detailed = [[
Lace is a simple access control engine modelled on Squid's acl syntax.
It provides a parser of rulesets and an engine to execute the parsed
rulesets.  It relies on the calling application to provide access
control types and then Lace runs the boolean logic and returns an
allow/deny result along with the location of the decision and any
description provided by it.]],
   homepage = "https://github.com/lunarmodules/lua-lace",
   license = "MIT"
}
build = {
   type = "builtin",
   modules = {
      lace = "lib/lace.lua",
      ["lace.builtin"] = "lib/lace/builtin.lua",
      ["lace.compiler"] = "lib/lace/compiler.lua",
      ["lace.engine"] = "lib/lace/engine.lua",
      ["lace.error"] = "lib/lace/error.lua",
      ["lace.lex"] = "lib/lace/lex.lua"
   }
}
