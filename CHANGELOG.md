# Changelog

## [2.5.0](https://github.com/nvimdev/guard.nvim/compare/v2.4.2...v2.5.0) (2025-11-08)


### Features

* migrate to _async ([#228](https://github.com/nvimdev/guard.nvim/issues/228)) ([92ff217](https://github.com/nvimdev/guard.nvim/commit/92ff21771c3ffcf63d3cf7eac3d533e40fc57eed))

## [2.4.2](https://github.com/nvimdev/guard.nvim/compare/v2.4.1...v2.4.2) (2025-11-07)


### Bug Fixes

* auto lint not attached ([#226](https://github.com/nvimdev/guard.nvim/issues/226)) ([5055978](https://github.com/nvimdev/guard.nvim/commit/50559788c78f7c7e0dd8142000507d717f5774f9))

## [2.4.1](https://github.com/nvimdev/guard.nvim/compare/v2.4.0...v2.4.1) (2025-10-11)


### Bug Fixes

* impure config reloading ([#223](https://github.com/nvimdev/guard.nvim/issues/223)) ([b185576](https://github.com/nvimdev/guard.nvim/commit/b1855762e97a51b54646c3ea0ddc2b5fc95d1ddf))

## [2.4.0](https://github.com/nvimdev/guard.nvim/compare/v2.3.2...v2.4.0) (2025-08-24)


### Features

* args can be a function ([#218](https://github.com/nvimdev/guard.nvim/issues/218)) ([d9e705b](https://github.com/nvimdev/guard.nvim/commit/d9e705b803d07eb83484e6220ce50ff076a1e8a8))

## [2.3.2](https://github.com/nvimdev/guard.nvim/compare/v2.3.1...v2.3.2) (2025-06-10)


### Bug Fixes

* multi filetype config chaining ([#214](https://github.com/nvimdev/guard.nvim/issues/214)) ([81e0f0a](https://github.com/nvimdev/guard.nvim/commit/81e0f0a781295ddc79d40cd3e549be65b6761edf))

## [2.3.1](https://github.com/nvimdev/guard.nvim/compare/v2.3.0...v2.3.1) (2025-05-16)


### Bug Fixes

* diag_fmt fallback logic, revert early formatter check ([#208](https://github.com/nvimdev/guard.nvim/issues/208)) ([55bbf64](https://github.com/nvimdev/guard.nvim/commit/55bbf64684414ad22f0e5f946c723b4e7ddc402c))

## [2.3.0](https://github.com/nvimdev/guard.nvim/compare/v2.2.0...v2.3.0) (2025-05-16)


### Features

* add refresh_diagnostic option ([#188](https://github.com/nvimdev/guard.nvim/issues/188)) ([6e0e8e5](https://github.com/nvimdev/guard.nvim/commit/6e0e8e5f27d9ed951675e022944c57b66191afc4))

## [2.2.0](https://github.com/nvimdev/guard.nvim/compare/v2.1.4...v2.2.0) (2025-05-16)


### Features

* make all diag_fmt params optional ([e02c358](https://github.com/nvimdev/guard.nvim/commit/e02c358dcab402a74a87135cc107104f2df83eeb))

## [2.1.4](https://github.com/nvimdev/guard.nvim/compare/v2.1.3...v2.1.4) (2025-04-13)


### Bug Fixes

* **nightly:** ditch deprecated method ([b59e4eb](https://github.com/nvimdev/guard.nvim/commit/b59e4eb57c9a8061260266b3ee594ffbb97092f8))
* resolve symlinks ([#201](https://github.com/nvimdev/guard.nvim/issues/201)) ([dfb3dd4](https://github.com/nvimdev/guard.nvim/commit/dfb3dd403704398c998a920a80f12746d42011a7))

## [2.1.3](https://github.com/nvimdev/guard.nvim/compare/v2.1.2...v2.1.3) (2025-03-05)


### Bug Fixes

* guard fmt autocmd lint trigger ([#198](https://github.com/nvimdev/guard.nvim/issues/198)) ([3f5a7b3](https://github.com/nvimdev/guard.nvim/commit/3f5a7b30be83b59b8a7883fe8e8ee479f3bc865e))

## [2.1.2](https://github.com/nvimdev/guard.nvim/compare/v2.1.1...v2.1.2) (2025-01-19)


### Bug Fixes

* **lint:** handle linter output correctly ([#192](https://github.com/nvimdev/guard.nvim/issues/192)) ([a125905](https://github.com/nvimdev/guard.nvim/commit/a1259051fa336f70f1040ef2aaf6015a7760d172))

## [2.1.1](https://github.com/nvimdev/guard.nvim/compare/v2.1.0...v2.1.1) (2025-01-13)


### Bug Fixes

* **api:** disable-fmt should set cache to nil ([eb9c55b](https://github.com/nvimdev/guard.nvim/commit/eb9c55b3771fa609a8fb480fbb446b646cdf62fa))

## [2.1.0](https://github.com/nvimdev/guard.nvim/compare/v2.0.0...v2.1.0) (2025-01-03)


### Features

* best effort indent preservation ([#186](https://github.com/nvimdev/guard.nvim/issues/186)) ([7a4fc3a](https://github.com/nvimdev/guard.nvim/commit/7a4fc3a5b9b2e8bca80a17a4c4e3737734a1a6c1))

## [2.0.0](https://github.com/nvimdev/guard.nvim/compare/v1.0.6...v2.0.0) (2024-12-23)


### ⚠ BREAKING CHANGES

* event API ([#181](https://github.com/nvimdev/guard.nvim/issues/181))

### Features

* event API ([#181](https://github.com/nvimdev/guard.nvim/issues/181)) ([25ba07f](https://github.com/nvimdev/guard.nvim/commit/25ba07f8ce72b3ba7cd585046182127c85ccc2cb))

## [1.0.6](https://github.com/nvimdev/guard.nvim/compare/v1.0.5...v1.0.6) (2024-12-13)


### Bug Fixes

* remove unused param in should_run ([0f24f76](https://github.com/nvimdev/guard.nvim/commit/0f24f7613e31322250198e0a3d11d93d6c5b5a46))

## [1.0.5](https://github.com/nvimdev/guard.nvim/compare/v1.0.4...v1.0.5) (2024-12-07)


### Bug Fixes

* attaching to nofile buffers ([#175](https://github.com/nvimdev/guard.nvim/issues/175)) ([246b7dc](https://github.com/nvimdev/guard.nvim/commit/246b7dcbc376efd749a94b24a2080af3de2ff733))

## [1.0.4](https://github.com/nvimdev/guard.nvim/compare/v1.0.3...v1.0.4) (2024-12-03)


### Bug Fixes

* **util:** wrong cmd value ([d3bf16f](https://github.com/nvimdev/guard.nvim/commit/d3bf16f11bd3e58f0c89a3b46942e69cfa646caf))

## [1.0.3](https://github.com/nvimdev/guard.nvim/compare/v1.0.2...v1.0.3) (2024-10-26)


### Bug Fixes

* impure formatting, lsp fallback not applied on load ([#171](https://github.com/nvimdev/guard.nvim/issues/171)) ([f439a46](https://github.com/nvimdev/guard.nvim/commit/f439a4620d7672089dcb76ec985a94c351575a6f))

## [1.0.2](https://github.com/nvimdev/guard.nvim/compare/v1.0.1...v1.0.2) (2024-10-24)


### Bug Fixes

* cmd not reflected in pure formatter errno ([4f6ecbe](https://github.com/nvimdev/guard.nvim/commit/4f6ecbe7bc653b589c1a7332fcd373601704f863))

## [1.0.1](https://github.com/nvimdev/guard.nvim/compare/v1.0.0...v1.0.1) (2024-10-10)


### Bug Fixes

* don't use error(...) ([#165](https://github.com/nvimdev/guard.nvim/issues/165)) ([c54adb4](https://github.com/nvimdev/guard.nvim/commit/c54adb49588fa37fd28db0b31fa9ed38ee0480ac))

## 1.0.0 (2024-10-05)


### ⚠ BREAKING CHANGES

* fine tune user interface ([#158](https://github.com/nvimdev/guard.nvim/issues/158))
* major refactor ([#150](https://github.com/nvimdev/guard.nvim/issues/150))

### ref

* major refactor ([#150](https://github.com/nvimdev/guard.nvim/issues/150)) ([6c3b3cb](https://github.com/nvimdev/guard.nvim/commit/6c3b3cb4e61446fa74ccec1a22f300efe541838a))


### Features

* **#44:** support env var specification ([#47](https://github.com/nvimdev/guard.nvim/issues/47)) ([c70cd92](https://github.com/nvimdev/guard.nvim/commit/c70cd92b2210a4bab740794f1bf5f55ccbaa5415))
* add `save_on_fmt` setup option ([#88](https://github.com/nvimdev/guard.nvim/issues/88)) ([2729748](https://github.com/nvimdev/guard.nvim/commit/2729748691f839949c75689f3fd37398e51e2bc8))
* add black for python format ([3c7c6cc](https://github.com/nvimdev/guard.nvim/commit/3c7c6cc93cf031cbea91b07b366ccc4107c8ca4b))
* add builtin support ([d629809](https://github.com/nvimdev/guard.nvim/commit/d62980906dfb255f8dc5fc9f6ff85d60f29ec07f))
* **docs:** revamp readme to focus on customizability ([#52](https://github.com/nvimdev/guard.nvim/issues/52)) ([6f02053](https://github.com/nvimdev/guard.nvim/commit/6f020539ff057a178d53592a21b5d58115b79c94))
* fine tune user interface ([#158](https://github.com/nvimdev/guard.nvim/issues/158)) ([f99cbcf](https://github.com/nvimdev/guard.nvim/commit/f99cbcfa02cdf5b9c827ed99c48d228135d3747c))
* format autocmd events ([#108](https://github.com/nvimdev/guard.nvim/issues/108)) ([c46f043](https://github.com/nvimdev/guard.nvim/commit/c46f043a1e2496ee42bdf8a499d3fbd93e137707))
* **formatter:** add `latexindent` ([#54](https://github.com/nvimdev/guard.nvim/issues/54)) ([9269fdb](https://github.com/nvimdev/guard.nvim/commit/9269fdbe4769428933bc4146b2d0603a795ff95c))
* ignore_patterns support string type ([a780f10](https://github.com/nvimdev/guard.nvim/commit/a780f1033efa4e65dfe88565d4461c406224763a))
* **linter:** shellcheck ([#53](https://github.com/nvimdev/guard.nvim/issues/53)) ([d54a332](https://github.com/nvimdev/guard.nvim/commit/d54a332062189ea74b4d002a86d304db4f77f3df))
* **lint:** let attributes be functions ([#112](https://github.com/nvimdev/guard.nvim/issues/112)) ([17e8884](https://github.com/nvimdev/guard.nvim/commit/17e888448f7d51b76a77b737ee74428189b989b9))
* **lint:** support selene ([#63](https://github.com/nvimdev/guard.nvim/issues/63)) ([35d79c2](https://github.com/nvimdev/guard.nvim/commit/35d79c28b371c195ba01fcc13fb566c5d85d72e7))
* more formatters ([#43](https://github.com/nvimdev/guard.nvim/issues/43)) ([44c5ada](https://github.com/nvimdev/guard.nvim/commit/44c5ada4995c56150a836dee325671d279e0f2ab))
* support find tool format config file and set extra arguments close [#38](https://github.com/nvimdev/guard.nvim/issues/38) ([a2d1b41](https://github.com/nvimdev/guard.nvim/commit/a2d1b41c1c1f620d8a78c1955a2dc4ea8461913a))
* support register config from setup ([65110bc](https://github.com/nvimdev/guard.nvim/commit/65110bcc8f70612d6a77a71c47928d10b16857db)), closes [#11](https://github.com/nvimdev/guard.nvim/issues/11)


### Bug Fixes

* **#111:** resolve windows executable paths ([07a6a4e](https://github.com/nvimdev/guard.nvim/commit/07a6a4ebeb5284750946d7a656c3e35d5fe77dfb))
* **#48:** preserve window views of formatted buffers ([6c6efa2](https://github.com/nvimdev/guard.nvim/commit/6c6efa2e0e941d0d894a2aa513ad2dae5fce1c6e))
* **#68:** handle formatter errors ([#75](https://github.com/nvimdev/guard.nvim/issues/75)) ([de02de7](https://github.com/nvimdev/guard.nvim/commit/de02de720dfe9b6839fb14dd63467b713018eed6))
* 24 ([c7edb1c](https://github.com/nvimdev/guard.nvim/commit/c7edb1c647e29544b42eb24b3793f9d1c5e3706b))
* breaking change in diag_fmt ([3b1fdbd](https://github.com/nvimdev/guard.nvim/commit/3b1fdbd44dfebeedec1fd6b3ef5045f55f95e2e0))
* broken commit ([#120](https://github.com/nvimdev/guard.nvim/issues/120)) ([6c27cc4](https://github.com/nvimdev/guard.nvim/commit/6c27cc46973a20ea27be4f4f7505370fd64a49ed))
* checkhealth, closes [#106](https://github.com/nvimdev/guard.nvim/issues/106) ([1225f99](https://github.com/nvimdev/guard.nvim/commit/1225f99b902afa59ad4270cdb112a34f71a05852))
* doau for lsp format ([#121](https://github.com/nvimdev/guard.nvim/issues/121)) ([3a27775](https://github.com/nvimdev/guard.nvim/commit/3a27775f155dbc2846cf7cce2ecc82451588e333))
* **doc:** fname type ([#101](https://github.com/nvimdev/guard.nvim/issues/101)) ([5a5fae6](https://github.com/nvimdev/guard.nvim/commit/5a5fae6269975813b46644f0a04f0feaa9e28945))
* ensure apply's validity when multiple formatting requests ([43ad797](https://github.com/nvimdev/guard.nvim/commit/43ad79798171b1e1e9d8975f3c73d9134a4f31b8))
* formatting ([c122927](https://github.com/nvimdev/guard.nvim/commit/c12292787b816815db57ef6ec574e2a824b19e39))
* funny bug ([#79](https://github.com/nvimdev/guard.nvim/issues/79)) ([e65a4fa](https://github.com/nvimdev/guard.nvim/commit/e65a4fa7be94d2b8e1d4238423f78b94f6b264fb))
* generic linter ([#134](https://github.com/nvimdev/guard.nvim/issues/134)) ([192fd1d](https://github.com/nvimdev/guard.nvim/commit/192fd1dad737148a95baf99ea360bddae66a5ff1))
* improve performance rubocop ([488780e](https://github.com/nvimdev/guard.nvim/commit/488780e73afd603f72867f39d4a193e0fda440e9))
* incoherent argument pos ([6a81e15](https://github.com/nvimdev/guard.nvim/commit/6a81e156bcde32282395dfd170c809955c2221c3))
* incorrect vim command ([14a8e35](https://github.com/nvimdev/guard.nvim/commit/14a8e35993c4513da1c93719234de09e7d3a91a2))
* latexindent breaks on non-unix ([bb5eb8f](https://github.com/nvimdev/guard.nvim/commit/bb5eb8fb8c5cc40f62b092a20f7458279e93d5db))
* LspAttach after GuardDisable errors out ([9b016ac](https://github.com/nvimdev/guard.nvim/commit/9b016acfd5dd0068dd96645103df2cc71453009e))
* multiple au attached  to one buf ([#117](https://github.com/nvimdev/guard.nvim/issues/117)) ([01bc09f](https://github.com/nvimdev/guard.nvim/commit/01bc09fb6e6d579e2e71f0408b7e890d935fb161))
* properly fix generic linters ([#138](https://github.com/nvimdev/guard.nvim/issues/138)) ([d478286](https://github.com/nvimdev/guard.nvim/commit/d4782860b7da344d7409edbe7ee3693d5b8ea226))
* range formatting ([#149](https://github.com/nvimdev/guard.nvim/issues/149)) ([69c25c4](https://github.com/nvimdev/guard.nvim/commit/69c25c4fd79c8078f64fed981cbd23eb7fed431d))
* remove vim.inspect ([83e2cb3](https://github.com/nvimdev/guard.nvim/commit/83e2cb3c34c286106967811857707c283f69f1fb))
* rubocop returns line + 1 ([5722b7a](https://github.com/nvimdev/guard.nvim/commit/5722b7a4b33732138f702af17f898f54552fa7c7))
* silent error message ([#71](https://github.com/nvimdev/guard.nvim/issues/71)) ([6e05a94](https://github.com/nvimdev/guard.nvim/commit/6e05a9451fc07a224940600b5e0a417f8fe37647))
* silent warning message & wrong exit status check ([#81](https://github.com/nvimdev/guard.nvim/issues/81)) ([d985721](https://github.com/nvimdev/guard.nvim/commit/d98572129b1550f72b6014c5693d0aaa8a39996b))
* splitting crlf lines ([#137](https://github.com/nvimdev/guard.nvim/issues/137)) ([383883a](https://github.com/nvimdev/guard.nvim/commit/383883af9cd4d7174e4f26fe83c6869447ddf544))
* typo ([#133](https://github.com/nvimdev/guard.nvim/issues/133)) ([19c2a28](https://github.com/nvimdev/guard.nvim/commit/19c2a2822d6087cb0489275ac7bc06a1467f3f3d))
* typo ([#144](https://github.com/nvimdev/guard.nvim/issues/144)) ([4b6812a](https://github.com/nvimdev/guard.nvim/commit/4b6812a2955d884fabd416acf83836543c811bc5))
* use vim.islist for new version ([ad38b54](https://github.com/nvimdev/guard.nvim/commit/ad38b5461ec3f40192a1305249b7fc350f8e891a))
* watch ft should respect fmt_on_save ([#97](https://github.com/nvimdev/guard.nvim/issues/97)) ([fc31ce5](https://github.com/nvimdev/guard.nvim/commit/fc31ce5c3aa3ed34bcbf11ccea19d1fd3ec13e30))


### Reverts

* remove opt ([81a0995](https://github.com/nvimdev/guard.nvim/commit/81a0995f07cc370fbf15d6d03abc4b1f8651d23f))
