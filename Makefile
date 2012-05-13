all: test

TEST_MODULES := lace.lex

LUA := LUA_PATH="$(shell pwd)/lib/?.lua;$(shell pwd)/extras/luacov/src/?.lua;$(HOME)/dev-bzr/luxio/?.lua;;" LUA_CPATH="$(HOME)/dev-bzr/luxio/?.so;;" lua5.1

clean:
	$(RM) luacov.report.out luacov.stats.out

distclean: clean
	find . -name "*~" -delete

.PHONY: test
test:
	@$(RM) luacov.stats.out
	@ERR=0; \
	for MOD in $(TEST_MODULES); do \
		echo "$${MOD}:"; \
		$(LUA) test/test-$${MOD}.lua; \
		test "x$$?" = "x0" || ERR=1; \
	done; \
	$(LUA) extras/luacov/src/bin/luacov -X test. $(TEST_MODULES); \
	exit $$ERR
