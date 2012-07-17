-- test/test-lace.builtin.lua
--
-- Lua Access Control Engine -- Tests for the builtins for Lace
--
-- Copyright 2012 Daniel Silverstone <dsilvers@digital-scurf.org>
--
-- For Licence terms, see COPYING
--

-- Step one, start coverage

local luacov = require 'luacov'

local builtin = require 'lace.builtin'
local engine = require 'lace.engine'

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

function suite.compile_builtin_allow_deny_badname()
   local cmdtab, msg = builtin.commands.allow({}, "badname")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("badname"), "Expected error should contain badname")
   assert(type(msg.words) == "table", "Internal error should contain a words table")
   assert(msg.words[1] == 1, "Internal error should reference word 1, the bad command name")
end

function suite.compile_builtin_allow_deny_noreason()
   local cmdtab, msg = builtin.commands.allow({}, "allow")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("Expected reason"), "Expected error should mention a lack of reason")
end

function suite.compile_builtin_allow_deny_novariables()
   local cmdtab, msg = builtin.commands.allow({}, "allow", "because")
   assert(type(cmdtab) == "table", "Result should be a table")
   assert(type(cmdtab.fn) == "function", "Result should contain a function")
   assert(type(cmdtab.args) == "table", "Result table should contain an args table")
   assert(cmdtab.args[1] == "allow", "Result args table should contain the given result 'allow'")
   assert(cmdtab.args[2] == "because", "Result args table should contain te given reason 'because'")
   assert(type(cmdtab.args[3]) == "table", "The third argument should be a table")
   assert(#cmdtab.args[3] == 0, "There should be no conditions")
end

function suite.run_builtin_allow_deny_novariables()
   local cmdtab, msg = builtin.commands.allow({}, "allow", "because")
   assert(type(cmdtab) == "table", "Result should be a table")
   assert(type(cmdtab.fn) == "function", "Result should contain a function")
   assert(type(cmdtab.args) == "table", "Result table should contain an args table")
   local result, msg = cmdtab.fn({}, unpack(cmdtab.args))
   assert(result == "allow", "Expected result should be 'allow'")
   assert(msg == "because", "Expected reason should be 'because'")
end

function suite.builtin_get_set_unconditional()
   builtin.get_set_last_unconditional_result("FOO")
   assert(builtin.get_set_last_unconditional_result() == "FOO",
	  "Result not saved")
end

function suite.builtin_get_set_last()
   builtin.get_set_last_result("FOO")
   assert(builtin.get_set_last_result() == "FOO",
	  "Result not saved")
end

function suite.run_builtin_allow_deny_unconditional_saved()
   builtin.get_set_last_unconditional_result()

   local cmdtab, msg = builtin.commands.allow({}, "allow", "because")
   assert(type(cmdtab) == "table", "Result should be a table")
   assert(type(cmdtab.fn) == "function", "Result should contain a function")
   assert(type(cmdtab.args) == "table", "Result table should contain an args table")
   local result, msg = cmdtab.fn({}, unpack(cmdtab.args))
   assert(result == "allow", "Expected result should be 'allow'")
   assert(msg == "because", "Expected reason should be 'because'")

   local last = builtin.get_set_last_unconditional_result()
   assert(last == "allow", "The last unconditional result was not allow?")
end

function suite.run_builtin_allow_deny_conditional_saved()
   builtin.get_set_last_result()

   local cmdtab, msg = builtin.commands.allow({}, "allow", "because", "fishes")
   assert(type(cmdtab) == "table", "Result should be a table")
   assert(type(cmdtab.fn) == "function", "Result should contain a function")
   assert(type(cmdtab.args) == "table", "Result table should contain an args table")

   local last = builtin.get_set_last_result()
   assert(last == "allow", "The last conditional result was not allow?")
end

function suite.compile_builtin_default_noresult()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.default(compctx, "default")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("Expected result"), "Expected error should mention a lack of result")
end

function suite.compile_builtin_default_resultbad()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.default(compctx, "default", "FISH")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("allow or deny"), "Expected error should mention a bad of result")
end

function suite.compile_builtin_default_extra_fluff()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.default(compctx, "default", "allow", "", "unwanted")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("additional"), "Expected error should mention additional content")
end

function suite.compile_builtin_default_ok()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.default(compctx, "default", "allow", "because")
   assert(type(cmdtab) == "table", "Successful compilation should return a table")
   assert(type(cmdtab.fn) == "function", "With a function")
   assert(type(cmdtab.args) == "table", "And an arg table")
   assert(cmdtab.fn() == true, "Default command should always return true")
   assert(type(compctx._lace.default) == "table", "Default should always set up the context")
   assert(type(compctx._lace.default.fn) == "function", "Default table should have a function like a rule")
end

function suite.compile_builtin_default_twice()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.default(compctx, "default", "allow", "")
   assert(type(cmdtab) == "table", "Successful compilation should return a table")
   local cmdtab, msg = builtin.commands.default(compctx, "default", "allow", "")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("change the"), "Expected error should mention changing the default")
end

function suite.compile_builtin_default_noreason()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.default(compctx, "default", "allow")
   assert(type(cmdtab) == "table", "Successful compilation should return a table")
   assert(type(cmdtab.fn) == "function", "With a function")
   assert(type(cmdtab.args) == "table", "And an arg table")
   assert(cmdtab.fn() == true, "Default command should always return true")
   assert(type(compctx._lace.default) == "table", "Default should always set up the context")
   assert(type(compctx._lace.default.fn) == "function", "Default table should have a function like a rule")
end

function suite.compile_builtin_define_noname()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.define(compctx, "define")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("Expected name"), "Expected error should mention a lack of name")
end

function suite.compile_builtin_define_badname()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.define(compctx, "define", "!fish")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("Bad name"), "Expected error should mention a bad name")
end

function suite.compile_builtin_define_noctype()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.define(compctx, "define", "fish")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("Expected control"), "Expected error should mention a lack of control type")
end

function suite.compile_builtin_define_badctype()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.define(compctx, "define", "fish", "fish")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("Unknown control"), "Expected error should mention unknown control type")
end

function suite.compile_builtin_define_ctype_errors()
   local function _fish()
      return false, { msg = "Argh" }
   end
   local compctx = {_lace = { controltype = { fish = _fish }}}
   local cmdtab, msg = builtin.commands.define(compctx, "define", "fish", "fish")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("Argh"), "Expected error should be passed through")
end

function suite.compile_builtin_define_ctype_errors_offset()
   local function _fish()
      return false, { msg = "Argh", words = {0} }
   end
   local compctx = {_lace = { controltype = { fish = _fish }}}
   local cmdtab, msg = builtin.commands.define(compctx, "define", "fish", "fish")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("Argh"), "Expected error should be passed through")
   assert(msg.words[1] == 2, "Error words should be offset by 2")
end

function suite.compile_builtin_define_ok()
   local function _fish()
      return {
	 JEFF = true
      }
   end
   local compctx = {_lace = { controltype = { fish = _fish }}}
   local cmdtab, msg = builtin.commands.define(compctx, "define", "fish", "fish")
   assert(type(cmdtab) == "table", "Successful compilation returns tables")
   assert(type(cmdtab.fn) == "function", "With functions")
   local ectx = {}
   local ok, msg = cmdtab.fn(ectx, unpack(cmdtab.args))
   assert(ok, "Running a define should work")
   assert(ectx._lace.defs.fish.JEFF, "definition should have passed through")
end

function suite.run_allow_deny_with_conditions_not_present()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.allow(compctx, "allow", "because", "cheese")
   assert(type(cmdtab) == "table", "Successful compilation returns tables")
   assert(type(cmdtab.fn) == "function", "With functions")
   local ectx = {}
   local ok, msg = cmdtab.fn(ectx, unpack(cmdtab.args))
   assert(ok == nil, "Running a conditional allow where the conditions are not defined should fail")
   assert(msg.msg:match("cheese"), "Resultant error should indicate missing variable name")
end

function suite.run_allow_deny_with_condition_present_erroring()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.allow(compctx, "allow", "because", "cheese")
   assert(type(cmdtab) == "table", "Successful compilation returns tables")
   assert(type(cmdtab.fn) == "function", "With functions")
   local _cheesetab = {
      fn = function() return nil, { msg = "CHEESE" } end,
      args = {}
   }
   local ectx = {_lace = {defs = { cheese = _cheesetab }}}
   local ok, msg = cmdtab.fn(ectx, unpack(cmdtab.args))
   assert(ok == nil, "Running a conditional allow where the conditions error should fail")
   assert(msg.msg:match("CHEESE"), "Resultant error should be passed")
end

function suite.run_allow_deny_with_condition_present_failing()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.allow(compctx, "allow", "because", "cheese")
   assert(type(cmdtab) == "table", "Successful compilation returns tables")
   assert(type(cmdtab.fn) == "function", "With functions")
   local _cheesetab = {
      fn = function() return false end,
      args = {}
   }
   local ectx = {_lace = {defs = { cheese = _cheesetab }}}
   local ok, msg = cmdtab.fn(ectx, unpack(cmdtab.args))
   assert(ok == true, "Running a conditional allow where the conditions fail should return continuation")
end


function suite.run_allow_deny_with_condition_present_passing()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.allow(compctx, "allow", "because", "cheese")
   assert(type(cmdtab) == "table", "Successful compilation returns tables")
   assert(type(cmdtab.fn) == "function", "With functions")
   local _cheesetab = {
      fn = function() return true end,
      args = {}
   }
   local ectx = {_lace = {defs = { cheese = _cheesetab }}}
   local ok, msg = cmdtab.fn(ectx, unpack(cmdtab.args))
   assert(ok == "allow", "Running a conditional allow where the conditions pass should return allow")
   assert(msg == "because", "Resulting in the reason given")
end

function suite.run_allow_deny_with_inverted_condition_present_failing()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.allow(compctx, "allow", "because", "!cheese")
   assert(type(cmdtab) == "table", "Successful compilation returns tables")
   assert(type(cmdtab.fn) == "function", "With functions")
   local _cheesetab = {
      fn = function() return true end,
      args = {}
   }
   local ectx = {_lace = {defs = { cheese = _cheesetab }}}
   local ok, msg = cmdtab.fn(ectx, unpack(cmdtab.args))
   assert(ok == true, "Running a conditional allow where the conditions fail should return continuation")
end


function suite.run_allow_deny_with_inverted_condition_present_passing()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.allow(compctx, "allow", "because", "!cheese")
   assert(type(cmdtab) == "table", "Successful compilation returns tables")
   assert(type(cmdtab.fn) == "function", "With functions")
   local _cheesetab = {
      fn = function() return false end,
      args = {}
   }
   local ectx = {_lace = {defs = { cheese = _cheesetab }}}
   local ok, msg = cmdtab.fn(ectx, unpack(cmdtab.args))
   assert(ok == "allow", "Running a conditional allow where the conditions pass should return allow")
   assert(msg == "because", "Resulting in the reason given")
end

function suite.compile_include_statement_noname()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.include(compctx, "include")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("ruleset name"), "Expected error should mention a lack of name")
end

function suite.compile_include_statement_noloader()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.include(compctx, "include", "fish")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("fish"), "Expected error should mention a name of unloadable content")
end

function suite.compile_safe_include_statement_noloader()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.include(compctx, "include?", "fish")
   assert(type(cmdtab) == "table", "Commands should be tables")
   assert(type(cmdtab.fn) == "function", "With a function")
   assert(type(cmdtab.args) == "table", "and arguments")
end

function suite.compile_include_statement_withloader()
   local function _loader(cctx, name)
      return name, "-- nada\n"
   end
   local compctx = {_lace = {loader=_loader}}
   local cmdtab, msg = builtin.commands.include(compctx, "include", "fish")
   assert(type(cmdtab) == "table", "Commands should be tables")
   assert(type(cmdtab.fn) == "function", "With a function")
   assert(type(cmdtab.args) == "table", "and arguments")
end

function suite.compile_include_statement_withloader_badcode()
   local function _loader(cctx, name)
      return name, "nada\n"
   end
   local compctx = {_lace = {loader=_loader}}
   local cmdtab, msg = builtin.commands.include(compctx, "include", "fish")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should return tables")
   assert(type(msg.msg) == "string", "Internal errors should have string messages")
   assert(msg.msg:match("nada"), "Expected error should mention the bad command name")
end

function suite.run_include_statement_withloader_good_code()
   local function _loader(cctx, name)
      return name, "--nada\n"
   end
   local compctx = {_lace = {loader=_loader}}
   local cmdtab, msg = builtin.commands.include(compctx, "include", "fish")
   assert(type(cmdtab) == "table", "Commands should be tables")
   assert(type(cmdtab.fn) == "function", "With a function")
   assert(type(cmdtab.args) == "table", "and arguments")
   local ectx = {}
   local result, msg = cmdtab.fn(ectx, unpack(cmdtab.args))
   assert(result == true, "Should be continuing as-is")
end

function suite.run_include_statement_withloader_good_code_allow()
   local function _loader(cctx, name)
      return name, "allow because\n"
   end
   local compctx = {_lace = {loader=_loader}}
   local cmdtab, msg = builtin.commands.include(compctx, "include", "fish")
   assert(type(cmdtab) == "table", "Commands should be tables")
   assert(type(cmdtab.fn) == "function", "With a function")
   assert(type(cmdtab.args) == "table", "and arguments")
   local ectx = {}
   local result, msg = cmdtab.fn(ectx, unpack(cmdtab.args))
   assert(result == "allow", "Should pass result")
   assert(msg == "because", "Should pass reason")
end

function suite.run_cond_include_present_erroring()
   local function _loader(cctx, name)
      return name, "allow because\n"
   end
   local compctx = {_lace = {loader=_loader}}
   local cmdtab, msg = builtin.commands.include(compctx, "include", "fish", "cheese")
   assert(type(cmdtab) == "table", "Commands should be tables")
   assert(type(cmdtab.fn) == "function", "With a function")
   assert(type(cmdtab.args) == "table", "and arguments")
   local ectx = {}
   local result, msg = cmdtab.fn(ectx, unpack(cmdtab.args))
   assert(result == nil, "Should fail gracefully")
   assert(msg.msg:match("cheese"), "Error should mention undefined variable")
end

function suite.run_cond_include_present_erroring()
   local function _loader(cctx, name)
      return name, "allow because\n"
   end
   local compctx = {_lace = {loader=_loader}}
   local cmdtab, msg = builtin.commands.include(compctx, "include", "fish", "cheese")
   assert(type(cmdtab) == "table", "Commands should be tables")
   assert(type(cmdtab.fn) == "function", "With a function")
   assert(type(cmdtab.args) == "table", "and arguments")
   local ectx = {
      _lace = {
	 defs = {
	    cheese = {
	       fn = function() return nil, { msg = "FAIL" } end,
	       args = {}
	    }
	 }
      }
   }
   local result, msg = cmdtab.fn(ectx, unpack(cmdtab.args))
   assert(result == nil, "Should fail gracefully")
   assert(msg.msg:match("FAIL"), "Error should mention undefined variable")
end

function suite.run_cond_include_present_failing()
   local function _loader(cctx, name)
      return name, "allow because\n"
   end
   local compctx = {_lace = {loader=_loader}}
   local cmdtab, msg = builtin.commands.include(compctx, "include", "fish", "cheese")
   assert(type(cmdtab) == "table", "Commands should be tables")
   assert(type(cmdtab.fn) == "function", "With a function")
   assert(type(cmdtab.args) == "table", "and arguments")
   local ectx = {
      _lace = {
	 defs = {
	    cheese = {
	       fn = function() return false end,
	       args = {}
	    }
	 }
      }
   }
   local result, msg = cmdtab.fn(ectx, unpack(cmdtab.args))
   assert(result == true, "Should continue blithely")
end

function suite.run_cond_include_present_passing()
   local function _loader(cctx, name)
      return name, "allow because\n"
   end
   local compctx = {_lace = {loader=_loader}}
   local cmdtab, msg = builtin.commands.include(compctx, "include", "fish", "cheese")
   assert(type(cmdtab) == "table", "Commands should be tables")
   assert(type(cmdtab.fn) == "function", "With a function")
   assert(type(cmdtab.args) == "table", "and arguments")
   local ectx = {
      _lace = {
	 defs = {
	    cheese = {
	       fn = function() return true end,
	       args = {}
	    }
	 }
      }
   }
   local result, msg = cmdtab.fn(ectx, unpack(cmdtab.args))
   assert(result == "allow", "Should propagate success")
   assert(msg == "because", "Should propagate reason")
end

function suite.compile_anyof_no_args()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.define(compctx, "define", "foo", "anyof")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should be tables")
   assert(msg.msg:match(", got none"), "Error should mention that there were no args")
end

function suite.compile_allof_no_args()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.define(compctx, "define", "foo", "allof")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should be tables")
   assert(msg.msg:match(", got none"), "Error should mention that there were no args")
end

function suite.compile_anyof_one_args()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.define(compctx, "define", "foo", "anyof", "foo")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should be tables")
   assert(msg.msg:match(", only got one"), "Error should mention that there was only one arg")
end

function suite.compile_allof_one_args()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.define(compctx, "define", "foo", "allof", "foo")
   assert(cmdtab == false, "Internal errors should return false")
   assert(type(msg) == "table", "Internal errors should be tables")
   assert(msg.msg:match(", only got one"), "Error should mention that there was only one arg")
end


function suite.compile_anyof_two_args()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.define(compctx, "define", "foo", "anyof", "foo", "bar")
   assert(type(cmdtab) == "table", "Successful compilations should return tables")
   assert(type(cmdtab.fn) == "function", "With functions")
   assert(type(cmdtab.args) == "table", "And arguments")
   assert(#cmdtab.args == 2, "There should be two args")
   assert(type(cmdtab.args[1]) == "string", "The first should be a table")
   assert(type(cmdtab.args[2]) == "table", "The second should be a bool")
   local ctrltab = cmdtab.args[2]
   assert(type(ctrltab) == "table", "Successfully compiled control functions should return tables")
   assert(type(ctrltab.fn) == "function", "With functions")
   assert(type(ctrltab.args) == "table", "And arguments")
   assert(#ctrltab.args == 2, "There should be two args")
   assert(type(ctrltab.args[1]) == "table", "The first should be a table")
   assert(type(ctrltab.args[2]) == "boolean", "The second should be a bool")
   assert(ctrltab.args[2] == true, "The anyof indicator should be true")
end

function suite.compile_allof_two_args()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.define(compctx, "define", "foo", "allof", "foo", "bar")
   assert(type(cmdtab) == "table", "Successful compilations should return tables")
   assert(type(cmdtab.fn) == "function", "With functions")
   assert(type(cmdtab.args) == "table", "And arguments")
   assert(#cmdtab.args == 2, "There should be two args")
   assert(type(cmdtab.args[1]) == "string", "The first should be a table")
   assert(type(cmdtab.args[2]) == "table", "The second should be a bool")
   local ctrltab = cmdtab.args[2]
   assert(type(ctrltab) == "table", "Successfully compiled control functions should return tables")
   assert(type(ctrltab.fn) == "function", "With functions")
   assert(type(ctrltab.args) == "table", "And arguments")
   assert(#ctrltab.args == 2, "There should be two args")
   assert(type(ctrltab.args[1]) == "table", "The first should be a table")
   assert(type(ctrltab.args[2]) == "boolean", "The second should be a bool")
   assert(ctrltab.args[2] == false, "The anyof indicator should be false")
end

function suite.run_anyof_two_args()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.define(compctx, "define", "jeff", "anyof", "foo", "bar")
   assert(type(cmdtab) == "table", "Successful compilations should return tables")
   local ectx = {
      _lace = {
	 defs = {
	    foo = {
	       fn = function() return true end,
	       args = {}
	    },
	    bar = {
	       fn = function() return false end,
	       args = {}
	    }
	 }
      }
   }
   local ok, msg = cmdtab.fn(ectx, unpack(cmdtab.args))
   assert(ok, "Running a define should work")
   assert(ectx._lace.defs.foo.fn, "definition should have passed through")
   assert(engine.test(ectx, "jeff"), "Any of true,false should be true")
end

function suite.run_anyof_two_args()
   local compctx = {_lace = {}}
   local cmdtab, msg = builtin.commands.define(compctx, "define", "jeff", "allof", "foo", "bar")
   assert(type(cmdtab) == "table", "Successful compilations should return tables")
   local ectx = {
      _lace = {
	 defs = {
	    foo = {
	       fn = function() return true end,
	       args = {}
	    },
	    bar = {
	       fn = function() return false end,
	       args = {}
	    }
	 }
      }
   }
   local ok, msg = cmdtab.fn(ectx, unpack(cmdtab.args))
   assert(ok, "Running a define should work")
   assert(ectx._lace.defs.foo.fn, "definition should have passed through")
   assert(engine.test(ectx, "jeff") == false, "All of true,false should be false")
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
