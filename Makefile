all: test

TEST_MODULES := lace lace.lex lace.compiler

LUA := LUA_PATH="$(shell pwd)/lib/?.lua;$(shell pwd)/extras/luacov/src/?.lua;;" lua5.1

clean:
	$(RM) luacov.report.out luacov.stats.out

distclean: clean
	find . -name "*~" -delete

.PHONY: test
test:
	@$(RM) luacov.stats.out
	@ERR=0; \
	for MOD in $(sort $(TEST_MODULES)); do \
		echo "$${MOD}:"; \
		$(LUA) test/test-$${MOD}.lua; \
		test "x$$?" = "x0" || ERR=1; \
	done; \
	$(LUA) extras/luacov/src/bin/luacov -X luacov. -X test. $(TEST_MODULES); \
	exit $$ERR

.PHONY: interactive
interactive:
	$(LUA) -e'lace=require"lace"' -i
