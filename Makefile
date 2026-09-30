MOJO_MODE ?= production
TEST_ONLINE ?= postgresql://postgres:postgres@localhost:5432/postgres
HARNESS_PERL_SWITCHES ?= -MDevel::Cover=-ignore,^blib/,-ignore,^templates/,-ignore,Net/SSLeay,-ignore,Dashboard/Plugin/Database.pm
COVERAGE_OPTS ?= PERL5OPT='$(HARNESS_PERL_SWITCHES)'
TEST_WRAPPER_COVERAGE ?= 1
ASSET_SOURCES := $(shell find assets -type f) package-lock.json vite.config.js vitest.config.js
BASE_BRANCH := $(shell BASES=$$(for i in upstream/main upstream/master origin/main origin/master main master; do git rev-parse --verify $$i 2>/dev/null; done ||:); git merge-base --independent $$BASES | head -n 1)
COMMIT_ARGS ?= --commits $(if $(BASE_BRANCH),$(BASE_BRANCH)..HEAD,HEAD) --verbose
PROVE ?= tools/prove_wrapper

.DEFAULT_GOAL := help

.PHONY: all
all: help

.PHONY: help
help: ## Display this help
	@echo Call one of the available targets:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
	@echo See README.md for more details

.PHONY: install-deps-js
install-deps-js: ## Install JS dependencies using npm clean-install
	npm clean-install --ignore-scripts
	npx playwright install --with-deps

.PHONY: install-deps-js-full
install-deps-js-full: ## Install JS dependencies using npm install (for development)
	npm install --ignore-scripts  # "npm clean-install" seems to not always build all assets. This is meant for development setups

.PHONY: install-deps-ubuntu
install-deps-ubuntu: ## Install system dependencies for Ubuntu
	sudo apt-get update
	sudo apt-get install -y libmagic-dev ruby-sass gitlint

.PHONY: install-deps-cpanm
install-deps-cpanm: ## Install Perl dependencies using cpanm
	cpanm -n --installdeps --with-feature=coverage .

.PHONY: install-deps
install-deps: install-deps-js install-deps-ubuntu install-deps-cpanm ## Install all dependencies (JS, system, Perl)

.PHONY: build
build: public/asset ## Build frontend assets

public/asset: $(ASSET_SOURCES)
	npm run build
	touch public/asset

.PHONY: start-postgres
start-postgres: ## Start a PostgreSQL container using podman
	podman run -p 5432:5432 -e POSTGRES_PASSWORD=postgres -d docker.io/library/postgres

.PHONY: run-mock
run-mock: build ## Run the dashboard in development mode with mock data
	MOJO_MODE=development \
	TEST_ONLINE=$(TEST_ONLINE) \
	./script/run-mock

.PHONY: run-dashboard-local
.NOTPARALLEL: run-dashboard-local
run-dashboard-local: install-deps-js-full build ## Run the dashboard locally with a real database
	git restore package-lock.json
	env DASHBOARD_CONF_OVERRIDE='{"pg":"${TEST_ONLINE}"}' script/dashboard daemon

.PHONY: run-mcp-stdio
run-mcp-stdio: ## Run the MCP stdio script
	./script/mcp-stdio

.PHONY: tidy-npm
tidy-npm: ## Format JS code using npm run lint:fix
	npm run lint:fix

.PHONY: tidy-perl
tidy-perl: ## Format Perl code using perltidy
	find . \( -iname '*.pm' -or -iname '*.pl' -or -iname '*.t' \) -not -ipath '*external*' -exec perltidy --pro=.../.perltidyrc -b -bext='/' {} \+
	git diff --exit-code

.PHONY: tidy
tidy: tidy-npm tidy-perl ## Format both JS and Perl code

.PHONY: test-unit
test-unit: public/asset ## Run Perl unit tests
	MOJO_MODE=$(MOJO_MODE) \
	TEST_ONLINE=$(TEST_ONLINE) \
	HARNESS_PERL_SWITCHES=$(HARNESS_PERL_SWITCHES) \
	"${PROVE}" -l t/*.t

.PHONY: test-ui
test-ui: public/asset ## Run Playwright UI tests
	MOJO_MODE=$(MOJO_MODE) \
	TEST_ONLINE=$(TEST_ONLINE) \
	TEST_WRAPPER_COVERAGE=$(TEST_WRAPPER_COVERAGE) \
	$(if $(TEST_WRAPPER_COVERAGE),$(COVERAGE_OPTS)) \
	"${PROVE}" -l t/*.t.js

.PHONY: test-js-unit
test-js-unit: ## Run JS unit tests
	npm run test:unit

.PHONY: check-audits-cpan
check-audits-cpan: ## Run security audits for Perl dependencies
	# CPANSA-Mojolicious-2024-58134, CPANSA-Mojolicious-2024-58135: session secrets handled in config
	#   See https://github.com/mojolicious/mojo/pull/2200
	# CPANSA-File-Temp-2011-4116: CVE-2011-4116
	#   See https://github.com/Perl-Toolchain-Gang/File-Temp/issues/14
	# CPANSA-perl-2026-8376: CVE-2026-8376 heap buffer overflow on 32-bit builds (not applicable)
	#   See https://github.com/Perl/perl5/commit/5e7f119eb2bb1181be908701f22bf7068e722f1c.patch
	# CPANSA-Archive-Tar-2026-42496, CPANSA-Archive-Tar-2026-9538, CPANSA-Archive-Tar-2026-42497:
	#   CVE-2026-42496, CVE-2026-9538, CVE-2026-42497 (transitive / not extracting untrusted archives)
	#   See https://github.com/jib/archive-tar-new/commit/17c873492a05eddc0de18c1485e0b2cccd5a9158.patch
	# CPANSA-Socket-2026-12087:
	#   CVE-2026-12087 (out-of-bounds heap read / not used)
	#   See https://github.com/Perl/perl5/commit/de19a0b0ad1900fef976c5c1400bd8f11ec6c6cb.patch
	# CPANSA-Storable-2026-57433:
	#   CVE-2026-57433 (signed integer overflow wrap / not deserializing untrusted data with Storable)
	#   See https://github.com/Perl/perl5/commit/e4f681784bcdeaa91ff02a2fa4cdcae5c46779d7.patch
	# CPANSA-perl-2026-13221, CPANSA-perl-2026-57432:
	#   CVE-2026-13221, CVE-2026-57432 (regex alternation trie overflow, pack template overflow / not applicable)
	#   See https://github.com/Perl/perl5/commit/03f74bbbd3a68350d926ee93d56ee4808c28c4c7.patch
	#   See https://github.com/Perl/perl5/commit/40754edc72dd3e513d758153c0e2f0215897740e.patch
	# CPANSA-perl-2026-15534:
	#   CVE-2026-15534 (regex superlinear cache OOB read/write / not matching attacker-controlled ~286MB subjects)
	#   See https://github.com/Perl/perl5/commit/54cf3d44cbbedd17d774e9a37921963e8fd5d0cb.patch
	#   See https://github.com/Perl/perl5/commit/568e6fd238867bb9e99fa3f47cba3169009239e0.patch
	# CPANSA-podlators-2026-82560:
	#   CVE-2026-82560 (Pod::Text CPU/memory exhaustion formatting attacker-supplied POD / not formatting untrusted POD)
	#   See https://github.com/rra/podlators/commit/70510174f69eb54aa6d617bde4e1402cd9b7c61f.patch
	PERL5LIB=~/perl5/lib/perl5:$$PERL5LIB PATH=~/perl5/bin:$$PATH cpan-audit deps . \
		--exclude CPANSA-Mojolicious-2024-58134 \
		--exclude CPANSA-Mojolicious-2024-58135 \
		--exclude CPANSA-File-Temp-2011-4116 \
		--exclude CPANSA-perl-2026-4176 \
		--exclude CPANSA-perl-2026-8376 \
		--exclude CPANSA-Archive-Tar-2026-42496 \
		--exclude CPANSA-Archive-Tar-2026-9538 \
		--exclude CPANSA-Archive-Tar-2026-42497 \
		--exclude CPANSA-Socket-2026-12087 \
		--exclude CPANSA-Storable-2026-57433 \
		--exclude CPANSA-perl-2026-13221 \
		--exclude CPANSA-perl-2026-57432 \
		--exclude CPANSA-perl-2026-15534 \
		--exclude CPANSA-podlators-2026-82560

.PHONY: check-audits-npm
check-audits-npm: ## Run security audits for JS dependencies
	npm audit --audit-level=high

.PHONY: check-audits
check-audits: check-audits-cpan check-audits-npm ## Run all security audits

.PHONY: lint-npm
lint-npm: ## Lint JS code and commit messages
	npm run lint
	npm run lint:commit -- $(COMMIT_ARGS)

.PHONY: checkstyle-perl
checkstyle-perl: tidy-perl ## Run Perl tidy

.PHONY: check-vite-deps
check-vite-deps:
	@node -e 'const pkg = require("./package.json"); if (pkg.devDependencies && pkg.devDependencies.vite) { console.error("Error: vite must be in dependencies for production builds (see 912fb927)"); process.exit(1); }'

.PHONY: checkstyle-npm
checkstyle-npm: lint-npm tidy-npm check-vite-deps ## Run JS lint, tidy and check vite deps

.PHONY: checkstyle
checkstyle: checkstyle-perl checkstyle-npm ## Run all checkstyle targets

.PHONY: only-test
only-test: test-unit test-ui test-js-unit ## Run all unit and UI tests without checkstyle

.PHONY: test
test: checkstyle only-test ## Run checkstyle and all tests

.PHONY: coverage
coverage: test ## Run tests and generate coverage report
	cover

.PHONY: only-test-coverage
only-test-coverage: only-test ## Run all tests and check coverage
	./script/check-coverage

.PHONY: test-coverage
test-coverage: only-test-coverage checkstyle ## Run all tests, check coverage and checkstyle
