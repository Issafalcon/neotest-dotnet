# we disable the `all` command because some external tool might run it automatically
.SUFFIXES:

all:

# runs all the test files.
test:
	nvim --version | head -n 1 && echo ''
	./tests/test.sh

# installs `mini.nvim`, used for both the tests and documentation.
deps:
	@mkdir -p deps
	git clone --depth 1 https://github.com/echasnovski/mini.doc.git deps/mini.doc.nvim
	git clone --depth 1 https://github.com/nvim-neotest/neotest.git deps/neotest
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim.git deps/plenary
	git clone --depth 1 https://github.com/nvim-treesitter/nvim-treesitter.git deps/nvim-treesitter
	git clone --depth 1 https://github.com/nvim-neotest/nvim-nio deps/nvim-nio

# installs deps before running tests, useful for the CI.
test-ci: deps test

# generates the documentation.
documentation:
	nvim --headless --noplugin -u ./scripts/minimal_init.lua \
		-c "lua require('mini.doc').setup()" \
		-c "lua require('mini.doc').generate()" \
		-c "qa!"

# installs deps before running the documentation generation, useful for the CI.
documentation-ci: deps documentation

# performs a lint check and fixes issue if possible, following the config in `stylua.toml`.
lint:
	stylua .
