LUAROCKS_PATH_CMD = luarocks path --no-bin --lua-version 5.1
BUSTED = eval $$(luarocks path --no-bin --lua-version 5.1) && busted --lua nlua
TEST_DIR = spec

.PHONY: test
test:
	@echo "Running tests..."
	@if [ -n "$(file)" ]; then \
		$(BUSTED) $(file); \
	else \
		$(BUSTED) $(TEST_DIR); \
	fi
