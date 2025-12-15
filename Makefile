LUAROCKS_PATH_CMD = luarocks path --no-bin --lua-version 5.1
TEST = luarocks test --local --lua-version=5.1
TEST_DIR = spec

.PHONY: test
test:
	@echo "Running tests..."
	@if [ -n "$(file)" ]; then \
		$(TEST) $(file); \
	else \
		$(TEST); \
	fi
