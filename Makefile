all: test

MODULES := lace lace.lex lace.compiler lace.builtin lace.engine lace.error
LUA_VER := 5.1

INST_BASE := /usr/local
INST_ROOT := $(DESTDIR)$(INST_BASE)/share/lua/$(LUA_VER)

MOD_FILES := $(patsubst %,%.lua,$(subst .,/,$(MODULES)))

install:
	mkdir -p $(INST_ROOT)/lace
	for MOD in $(sort $(MOD_FILES)); do \
		cp lib/$${MOD} $(INST_ROOT)/$${MOD}; \
	done

LUA := LUA_PATH="$(shell pwd)/lib/?.lua;$(shell pwd)/extras/luacov/src/?.lua;;" lua$(LUA_VER)

clean:
	$(RM) luacov.report.out luacov.stats.out

distclean: clean
	find . -name "*~" -delete

.PHONY: example
example:
	$(LUA) example/lace-example.lua

.PHONY: test
test:
	@$(RM) luacov.stats.out
	@ERR=0; \
	for MOD in $(sort $(MODULES)); do \
		echo -n "$${MOD}: "; \
		$(LUA) test/test-$${MOD}.lua; \
		test "x$$?" = "x0" || ERR=1; \
	done; \
	$(LUA) extras/luacov/src/bin/luacov -X luacov. -X test. $(MODULES); \
	exit $$ERR

.PHONY: interactive
interactive:
	$(LUA) -e'lace=require"lace"' -i
