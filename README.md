[![Luacheck](https://github.com/lunarmodules/lua-lace/workflows/Luacheck/badge.svg)](https://github.com/lunarmodules/lua-lace/actions)
[![Tests](https://img.shields.io/github/actions/workflow/status/lunarmodules/lua-lace/test.yml?branch=master&label=Unix%20build&logo=linux)](https://github.com/lunarmodules/lua-lace/actions)
[![Coveralls code coverage](https://img.shields.io/coveralls/github/lunarmodules/lua-lace?logo=coveralls)](https://coveralls.io/github/lunarmodules/lua-lace)

Lua Access Control Engine - Lace
================================

Lace is a simple access control engine modelled on Squid's acl syntax.
It provides a parser of rulesets and an engine to execute the parsed
rulesets.  It relies on the calling application to provide access
control types and then Lace runs the boolean logic and returns an
allow/deny result along with the location of the decision and any
description provided by it.  Lace also handles errors in the control
callbacks to always return gracefully in the form:

    local result, reason = engine:run(context)
    
    if result == nil then
       report_error(reason)
    elseif result == false then
       handle_deny(reason)
    else
       handle_allow(reason)
    end

Lace is designed to allow a ruleset loaded into an engine to be run
multiple times with different contexts, each time unaffected by the
last.  Of course, this relies on various idempotency requirements
being placed on the control type callbacks, but that is covered in the
usage documentation.

For some examples of using Lace, please see the examples/ tree.

Thanks
======

Thanks go to Codethink Limited for sponsoring development by means of tea,
biscuits and long lunch hours.
