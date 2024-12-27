# Changelog

## [1.7.0](https://github.com/Issafalcon/neotest-dotnet/compare/v1.6.5...v1.7.0) (2024-12-27)


### Features

* **runsettings:** Adds support for runsettings files ([4c82420](https://github.com/Issafalcon/neotest-dotnet/commit/4c8242099d6c222e8340c0a09bc34df2bac81dcf))
* support luarocks/rocks.nvim ([c7ccbaa](https://github.com/Issafalcon/neotest-dotnet/commit/c7ccbaaee488c5668ccd9b6f7b889fda6344fa51))


### Bug Fixes

* add opts for legacy behavior for Quer:iter_matches ([da35fac](https://github.com/Issafalcon/neotest-dotnet/commit/da35fac262cb6bd2c7a99c7c8f3e2ecc465b9a35))
* use vim.iter():flatten() instead of deprecated vim.tbl_flatten() on 0.11+ ([a4324ce](https://github.com/Issafalcon/neotest-dotnet/commit/a4324cea9dbd13a076d31aa2fd23e0d35b4292c5))
* **workflow:** Updating supported versions ([78a3620](https://github.com/Issafalcon/neotest-dotnet/commit/78a3620c339060afed99ef7af7e76325f3f7110e))

## [1.6.5](https://github.com/Issafalcon/neotest-dotnet/compare/v1.6.4...v1.6.5) (2024-06-01)


### Bug Fixes

* **103:** Fixes remaining file scoped namespace tests ([cc56f9c](https://github.com/Issafalcon/neotest-dotnet/commit/cc56f9c50f0146740ab4c9a84fe043197172d1d9))
* **103:** Installing nio as deps to fix tests ([1ad233e](https://github.com/Issafalcon/neotest-dotnet/commit/1ad233eb83235c84def30636dcc64af456e30e44))
* **nunit:** Tests fix for one test ([9238353](https://github.com/Issafalcon/neotest-dotnet/commit/923835348685fe90aa660d3d0a6eb2d63e3d5c63))

## [1.6.4](https://github.com/Issafalcon/neotest-dotnet/compare/v1.6.3...v1.6.4) (2024-05-26)


### Bug Fixes

* **xunit:** TS query for latest parser ([2165a39](https://github.com/Issafalcon/neotest-dotnet/commit/2165a39262ccc3de9ff99be1a427927918c25b42))

## [1.6.3](https://github.com/Issafalcon/neotest-dotnet/compare/v1.6.2...v1.6.3) (2024-04-13)


### Bug Fixes

* **xunit:** TS query for Fact attribute ([8f8ab91](https://github.com/Issafalcon/neotest-dotnet/commit/8f8ab9123e7664c9d0fd4547979d2b9f09b0da89)), closes [#96](https://github.com/Issafalcon/neotest-dotnet/issues/96)

## [1.6.2](https://github.com/Issafalcon/neotest-dotnet/compare/v1.6.1...v1.6.2) (2024-03-13)


### Bug Fixes

* **xunit:** - Caching dotnet test run to discover names ([209338d](https://github.com/Issafalcon/neotest-dotnet/commit/209338d209674bf714f63a9027c81ef3f849fada))

## [1.6.1](https://github.com/Issafalcon/neotest-dotnet/compare/v1.6.0...v1.6.1) (2024-03-07)


### Bug Fixes

* **dap-args:** Fixes dap args after previous PR changes ([41cdee9](https://github.com/Issafalcon/neotest-dotnet/commit/41cdee9536a3b504004fc7d2eefce53b0a1cd56e))

## [1.6.0](https://github.com/Issafalcon/neotest-dotnet/compare/v1.5.3...v1.6.0) (2024-02-22)


### Features

* **dotnet-test:** Fixes nesting issue with parameterized tests ([56d3e56](https://github.com/Issafalcon/neotest-dotnet/commit/56d3e56ba584bfe61fa21fdde165e1f5a887b05c))
* **dotnet-test:** Supports discovery when using custom display name ([8af2c78](https://github.com/Issafalcon/neotest-dotnet/commit/8af2c7889ade9c54b7e96552cd6ac05f0589fe9a))
* **scope:** Fixes parent name of parameterized tests ([4ebc336](https://github.com/Issafalcon/neotest-dotnet/commit/4ebc336c19646791b75c2ae1a30f2b8e403b9d63))
* **scope:** Fixes xunit query ([ca5640a](https://github.com/Issafalcon/neotest-dotnet/commit/ca5640a5f82e4ab2d7195ae588412e68c0eb3522))


### Bug Fixes

* **dotnet-test:** Fixes discover_positions tests ([afdd1d4](https://github.com/Issafalcon/neotest-dotnet/commit/afdd1d4f54fc8e9ec6aeb7c7f5138fad97cdaf9a))
* **dotnet-test:** Fixes specflow for xunit ([6e24029](https://github.com/Issafalcon/neotest-dotnet/commit/6e24029d4006feac6d69e43ff5302c926c303de9))
* **dotnet-test:** Updates mstest framework utils ([ed70202](https://github.com/Issafalcon/neotest-dotnet/commit/ed70202801619e2248f83698bcf8ebb22e7fc035))

## [1.5.3](https://github.com/Issafalcon/neotest-dotnet/compare/v1.5.2...v1.5.3) (2024-02-07)


### Bug Fixes

* **custom-attributes:** do not ignore the result of `tbl_flatten` ([f681bad](https://github.com/Issafalcon/neotest-dotnet/commit/f681bad2ab8af4eeed807a97c5ca294c60022de9))
* **custom-attributes:** Fix formatting to pass linter ([9d06182](https://github.com/Issafalcon/neotest-dotnet/commit/9d06182a89d2746e6250dc34719ad706045e1c8a))
* **customattributes:** Adds unit test for standalone custom attribute ([5819656](https://github.com/Issafalcon/neotest-dotnet/commit/581965658105019e8ea722a9d331fb62dcc7e2fb))

## [1.5.2](https://github.com/Issafalcon/neotest-dotnet/compare/v1.5.1...v1.5.2) (2023-12-22)


### Bug Fixes

* **result-utils:** Fixes issue with trx when display name is specified ([7668ff9](https://github.com/Issafalcon/neotest-dotnet/commit/7668ff9122939a97e7f423670868ed95ccc401e6))

## [1.5.1](https://github.com/Issafalcon/neotest-dotnet/compare/v1.5.0...v1.5.1) (2023-10-25)


### Bug Fixes

* **72:** Fixes NUnit specflow test discovery issues ([cad1258](https://github.com/Issafalcon/neotest-dotnet/commit/cad1258316836b9ba4526c41e60f1e9e0490f0fe))

## [1.5.0](https://github.com/Issafalcon/neotest-dotnet/compare/v1.4.0...v1.5.0) (2023-08-13)


### Features

* **nunit:** Adds support for testcasesource attribute ([58e7de7](https://github.com/Issafalcon/neotest-dotnet/commit/58e7de7139cf73322951b0303e4301b0f274e6b4))

## [1.4.0](https://github.com/Issafalcon/neotest-dotnet/compare/v1.3.0...v1.4.0) (2023-06-20)


### Features

* **dotnet-args:** Adds ability to provide additional dotnet args ([3fecfa5](https://github.com/Issafalcon/neotest-dotnet/commit/3fecfa59813bf243800e804c5882b163bc11d335))


### Bug Fixes

* **dap-strategy:** Removing the need to use the workaround custom debug ([bf5d37d](https://github.com/Issafalcon/neotest-dotnet/commit/bf5d37ded7a86b9d15887be88a81c791b2692524))

## [1.3.0](https://github.com/Issafalcon/neotest-dotnet/compare/v1.2.2...v1.3.0) (2023-06-04)


### Features

* **xUnit-classdata:** Adding additional FQN of test to errorinfo ([7c33ea9](https://github.com/Issafalcon/neotest-dotnet/commit/7c33ea95fd5f6bd091cf765c8443e4e539335f0e))
* **xUnit-classdata:** Adds backward compatible support for ts queries ([298f5c9](https://github.com/Issafalcon/neotest-dotnet/commit/298f5c9f0fd1fec766cb888dbad5d42a9198e6cc))
* **xUnit-classdata:** Adds classdata discovery position tests ([54575fc](https://github.com/Issafalcon/neotest-dotnet/commit/54575fc44ef506afdd803a15731d9b449e3df664))
* **xUnit-classdata:** Adds in result_utils unit tests ([188f817](https://github.com/Issafalcon/neotest-dotnet/commit/188f817c2ff92ba08a81b087a2a4532661f764f1))
* **xUnit-classdata:** Fixes linkage of classdata test groups ([0953ad0](https://github.com/Issafalcon/neotest-dotnet/commit/0953ad0ed4d2901b006a403373d95d4c8091686e))


### Bug Fixes

* **queries:** Fixes the incorrect TS API usage for older versions ([f2bd4e8](https://github.com/Issafalcon/neotest-dotnet/commit/f2bd4e88bb0b4adf3dc2669872fc162fd9dbb4f2))
* **treesitter:** Further attempt to fix backwards compatibil;ity ([8194245](https://github.com/Issafalcon/neotest-dotnet/commit/81942459d9387b4b2bbb28716b281838b6361a9d))

## [1.2.2](https://github.com/Issafalcon/neotest-dotnet/compare/v1.2.1...v1.2.2) (2023-04-17)


### Bug Fixes

* **43:** Adding new custom strategy for debugging ([1f533c9](https://github.com/Issafalcon/neotest-dotnet/commit/1f533c930cdd2f6ba43fcacf4f917c0290a3fe7b))
* **43:** Working fix for debug output using custom strategy ([ff0f3b1](https://github.com/Issafalcon/neotest-dotnet/commit/ff0f3b135890c6d6c188316bc0c3e18c762e6e85))

## [1.2.1](https://github.com/Issafalcon/neotest-dotnet/compare/v1.2.0...v1.2.1) (2023-04-15)


### Bug Fixes

* **27:** Fix duplicate class query matcher for nunit ([5b8687f](https://github.com/Issafalcon/neotest-dotnet/commit/5b8687f0afbbcd44257ca550867b14c745f99418))
* **nested-classes:** Fixes position_id for nested classes ([ae0aa03](https://github.com/Issafalcon/neotest-dotnet/commit/ae0aa0314b88e07ee096c6784926a7e918a24e43))

## [1.2.0](https://github.com/Issafalcon/neotest-dotnet/compare/v1.1.0...v1.2.0) (2023-04-15)


### Features

* new async library ([3af29c5](https://github.com/Issafalcon/neotest-dotnet/commit/3af29c5d20c73700c5dabd14a91fd2fd925ee547))

## [1.1.0](https://github.com/Issafalcon/neotest-dotnet/compare/v1.0.0...v1.1.0) (2023-02-05)


### Features

* **sln-root:** Creating multiple specs for direcotory tree ([e6d91ed](https://github.com/Issafalcon/neotest-dotnet/commit/e6d91eda40c56e7fd7e7257da9c3204eab5d11f2))
* **sln-root:** Fix for file type position and more unit tests ([0c76827](https://github.com/Issafalcon/neotest-dotnet/commit/0c76827f948c25d45b58339d3e38e1d90502ab50))


### Bug Fixes

* **sln-root-dir:** Provides option to determine the root dir ([0905484](https://github.com/Issafalcon/neotest-dotnet/commit/0905484bda666c33bfbf7ae592cefd45e9543742))
* **sln-test-runs:** Fixing the error when running entire test suite ([e1697f5](https://github.com/Issafalcon/neotest-dotnet/commit/e1697f548b1b31c2a339a96bf29c6d10b31485db))

## 1.0.0 (2023-01-28)


### Features

* **build_spec:** Adding in initial dotnet test command to run tests ([101860b](https://github.com/Issafalcon/neotest-dotnet/commit/101860b8fd700e06762a2a408d07665996621696))
* **console-output:** Fixing console output to pick up results ([9dcd154](https://github.com/Issafalcon/neotest-dotnet/commit/9dcd1547ca36d583b916cc43af621e2f50de49f8))
* **custom_attributes:** Adding initial support for custom xunit attrs ([83b0a36](https://github.com/Issafalcon/neotest-dotnet/commit/83b0a36992b7e58bf7f5f482425d544c98b43e98))
* **custom_attributes:** Adding some attribute utils ([a6ce6c4](https://github.com/Issafalcon/neotest-dotnet/commit/a6ce6c47556bd7c7ac95d4c66728111cd80ab184))
* **custom_attributes:** Finalizing the custom attribute support ([2dd016d](https://github.com/Issafalcon/neotest-dotnet/commit/2dd016de88bb6ec6590c06a1712aa3993739b9ae))
* **debugging:** Debug support now working for Xunit (with some bugs) ([95dd030](https://github.com/Issafalcon/neotest-dotnet/commit/95dd030e2d1c2244f2708e1d5809f2f4e40dd851))
* **debugging:** Initial stab at debugging ([075f7ed](https://github.com/Issafalcon/neotest-dotnet/commit/075f7ed2369a81ca4133997b86a443122bb8cb6e))
* **debugging:** Updating README with debug info ([c0ceac4](https://github.com/Issafalcon/neotest-dotnet/commit/c0ceac4fb57e7dcb1e7c6b8230010c54d3abccba))
* **discover-positions:** Messing around with async scheduler ([4d6e5de](https://github.com/Issafalcon/neotest-dotnet/commit/4d6e5dea007b4ccf7836630763bb7e4b97b49542))
* **discover-positions:** moving over to using treesitter queries ([33a391f](https://github.com/Issafalcon/neotest-dotnet/commit/33a391f99107e31c64ad5ba51e79b8908be59751))
* **mpv:** Adding code for making requests on omnisharp-lsp ([f04370a](https://github.com/Issafalcon/neotest-dotnet/commit/f04370a6d440800bd896788bf4c17e8d0d862486))
* **mstest-support:** Adds support for mstest ([f6c3d20](https://github.com/Issafalcon/neotest-dotnet/commit/f6c3d20a97fcc9a9029537f8e7313b11a0eb14a8))
* **mstest-support:** Tidying up some duplicate code ([acea1fa](https://github.com/Issafalcon/neotest-dotnet/commit/acea1fa62163f900da6101f2e1758acb9ea6d798))
* **mvp:** Adding stylua and creating first skeleton outline of adapter ([572a085](https://github.com/Issafalcon/neotest-dotnet/commit/572a0859b50548aa01fb09c1e1a4e1969da90157))
* **mvp:** Additional omnisharp code for making requests on lsp ([9830d7f](https://github.com/Issafalcon/neotest-dotnet/commit/9830d7fafab7b7d93b6fade2aa56e31afe4ec017))
* **nunit-support:** First attempt to get strategy pattern working ([41dd81a](https://github.com/Issafalcon/neotest-dotnet/commit/41dd81a48f01ec3f422939782ed6d89383542eb6))
* **nunit-support:** Fixing the parameterized tests for nunit ([d4ad3c8](https://github.com/Issafalcon/neotest-dotnet/commit/d4ad3c8b96009f6a2afc0b34821586e09d174600))
* **nunit-support:** Marking nunit as supported in README ([f49e2ce](https://github.com/Issafalcon/neotest-dotnet/commit/f49e2ce094c41bf80ebddd9daccd3aa49e9315d6))
* **nunit-support:** Refactoring some of the ts-queries ([fdce4f0](https://github.com/Issafalcon/neotest-dotnet/commit/fdce4f0954b2c4f4c61cdcc244344b21a1b09f8e))
* **nunit-support:** Refactoring test utils to support multiframework ([2faffa7](https://github.com/Issafalcon/neotest-dotnet/commit/2faffa7586e61670f9f1689c569c643274b52a62))
* **nunit-support:** Still trying to get framework strategies to work ([d96c01c](https://github.com/Issafalcon/neotest-dotnet/commit/d96c01c6c1cbee73108ab4cc8d9f8d0f95ead7f2))
* **nunit-support:** Strategy pattern discovery for framework working ([762f33f](https://github.com/Issafalcon/neotest-dotnet/commit/762f33fa9894331d29d5100aae94a3256ab438f3))
* **omnisharp-removal:** Removing dependency on omnisharp in build_pos ([88c4215](https://github.com/Issafalcon/neotest-dotnet/commit/88c4215c98487d8bb3df324b1f7865f9ca630177))
* **omnisharp-removal:** Removing last dependency on LSP ([bcac8b5](https://github.com/Issafalcon/neotest-dotnet/commit/bcac8b51ec1f6d030bee0de3b213493b909b3676))
* **omnisharp-removal:** Tidying up specflow queries, add filter_dir ([2efa9fc](https://github.com/Issafalcon/neotest-dotnet/commit/2efa9fc7e86184537d37978c0c50c5dce6600f18))
* **parser:** Adding parser to get the tree of node elements ([d885034](https://github.com/Issafalcon/neotest-dotnet/commit/d88503440fc0efc6a20c798d52d275753677f900))
* **positions:** Updated parse function so it correctly parses tests ([57c2373](https://github.com/Issafalcon/neotest-dotnet/commit/57c237362b8248c7215f15fbdef5cfac64b75fba))
* **results:** Adding xml parsing for trx files ([1f25ebc](https://github.com/Issafalcon/neotest-dotnet/commit/1f25ebc92738e21eb1166222fc2195fdde9eddba))
* **results:** First iteration of test result output ([92a34a4](https://github.com/Issafalcon/neotest-dotnet/commit/92a34a49494338b19c715ccd64296fdb4635f8b5))
* **results:** Marshalling results into intermediate objects ([5dcd232](https://github.com/Issafalcon/neotest-dotnet/commit/5dcd23280be97999e3c04c3fe829c4fd03166918))
* stateless parsing ([493eb22](https://github.com/Issafalcon/neotest-dotnet/commit/493eb22bd1bb7e7651d09a89462b74c6b1c2f33a))
* **stateless-parsing:** Fixing naming of xunit tests ([2efabdc](https://github.com/Issafalcon/neotest-dotnet/commit/2efabdc433e856a61310fe63d7ee7255ae684594))
* **stateless-parsing:** Fixing the position ID for parameterized tests ([dfec475](https://github.com/Issafalcon/neotest-dotnet/commit/dfec475e241f54f65693188cdb0f126b849f9af5))
* **stateless-parsing:** Tidying up redundant code ([102b04a](https://github.com/Issafalcon/neotest-dotnet/commit/102b04a743e132397d75a60f34cbe18cbff503ab))
* **test-check:** Moving code structure according to convention ([6323e23](https://github.com/Issafalcon/neotest-dotnet/commit/6323e23fad9e5476d6304fc8fdd76250ef79a72a))
* **xunit-parameterized:** Initial attempt to split test queries ([269e50f](https://github.com/Issafalcon/neotest-dotnet/commit/269e50fd5170e0a21c03494976e877d810b7f19c))
* **xunit:** Getting parameterized tests to show up in summary ([fba1844](https://github.com/Issafalcon/neotest-dotnet/commit/fba1844501ff5cc49ecdb1642cc36e09c159fed8))
* **xunit:** Polishing support for parameterized tests xunit ([fb2013a](https://github.com/Issafalcon/neotest-dotnet/commit/fb2013aa32ba7abcc0405176c73775984b56a819))


### Bug Fixes

* **22:** Fixing issue when using directives for test framework missing ([f8d62dd](https://github.com/Issafalcon/neotest-dotnet/commit/f8d62dd61505fdfd3a3f413830f50cdbcad2ca9e))
* **28:** Use --results-directory instead of -r ([d313033](https://github.com/Issafalcon/neotest-dotnet/commit/d313033285f8ec0316d69874ba8921c7fef92131))
* **build-positions:** Adds support for file scoped namespace syntax ([e40cdf5](https://github.com/Issafalcon/neotest-dotnet/commit/e40cdf5547c523c0acc67f4192c8183b0126d71c))
* **custom_attributes:** Fixes dicovery error when custom attributes not provided ([30d2c02](https://github.com/Issafalcon/neotest-dotnet/commit/30d2c02df17ecc965879c7e0ad338ef4f4f0a087))
* Dynamically parameterized tests name matching ([109aec0](https://github.com/Issafalcon/neotest-dotnet/commit/109aec0e729999d12a3a1c70e4537b298cfc2aa6)), closes [#40](https://github.com/Issafalcon/neotest-dotnet/issues/40)
* **error-handling:** Handling LSP nil responses ([c53dedc](https://github.com/Issafalcon/neotest-dotnet/commit/c53dedc61c536a8144bfcdd71195322922b00ad7))
* **nunit-support:** Change test attribute variable name to match name used in queries ([c324f2f](https://github.com/Issafalcon/neotest-dotnet/commit/c324f2f0741821e31207e71efa0d5b634fccd890))
* **results:** Fixed bug in nunit skipped tests causing error ([acff63a](https://github.com/Issafalcon/neotest-dotnet/commit/acff63abb905959d6687b4f415752c18e13ba40e))
* **results:** Fixing unknown status output for skipped tests ([9b2e1e0](https://github.com/Issafalcon/neotest-dotnet/commit/9b2e1e087309405a7390a6820f0973093bc64d63))
* **results:** Handling runtime errors when no test results ([2fae64b](https://github.com/Issafalcon/neotest-dotnet/commit/2fae64b134a403ae75d3868d6e999b803eac9b48))
* **run-tests:** Fixing fully qualified path on windows ([8b4b5e4](https://github.com/Issafalcon/neotest-dotnet/commit/8b4b5e452b1702ab94d5abca7023d13231694781))
* **ts-queries:** Fixing name of unit test query file ([74649fc](https://github.com/Issafalcon/neotest-dotnet/commit/74649fca140ce79da23ee32112cac62a1ebc0e69))
