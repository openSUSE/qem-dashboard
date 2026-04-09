MOJO_MODE ?= production
TEST_ONLINE ?= postgresql://postgres:postgres@localhost:5432/postgres
HARNESS_PERL_SWITCHES ?= -MDevel::Cover=-ignore,^blib/,-ignore,^templates/,-ignore,Net/SSLeay,-ignore,Dashboard/Plugin/Database.pm
COVERAGE_OPTS ?= PERL5OPT='$(HARNESS_PERL_SWITCHES)'
TEST_WRAPPER_COVERAGE ?= 1
ASSET_SOURCES := $(shell find assets -type f) package-lock.json vite.config.js vitest.config.js
COMMIT_ARGS ?= --last
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
	sudo apt-get install -y libmagic-dev ruby-sass

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
	bash -c 'shopt -s extglob globstar nullglob; perltidy --pro=.../.perltidyrc -b -bext='/' **/*.p[lm] **/*.t && git diff --exit-code'

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
	# CPANSA-YAML-LibYAML-2025-001: CVE-2025-40908 (path traversal)
	#   See https://github.com/ingydotnet/yaml-libyaml-pm/issues/120
	# CPANSA-YAML-LibYAML-2012-1152, CPANSA-YAML-LibYAML-2014-9130, CPANSA-YAML-LibYAML-2016-01:
	#   See https://github.com/ingydotnet/yaml-libyaml-pm/issues/45
	# CPANSA-Compress-Raw-Zlib-2026-3381: CVE-2026-3381
	#   See https://www.cve.org/CVERecord?id=CVE-2026-27171
	PERL5LIB=~/perl5/lib/perl5:$$PERL5LIB PATH=~/perl5/bin:$$PATH cpan-audit deps . \
		--exclude CPANSA-Mojolicious-2024-58134 \
		--exclude CPANSA-Mojolicious-2024-58135 \
		--exclude CPANSA-File-Temp-2011-4116 \
		--exclude CPANSA-YAML-LibYAML-2025-001 \
		--exclude CPANSA-YAML-LibYAML-2012-1152 \
		--exclude CPANSA-YAML-LibYAML-2014-9130 \
		--exclude CPANSA-YAML-LibYAML-2016-01 \
		--exclude CPANSA-Compress-Raw-Zlib-2026-3381

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
checkstyle-perl: tidy-perl check-audits-cpan ## Run Perl tidy and CPAN audits

.PHONY: check-vite-deps
check-vite-deps:
	@node -e 'const pkg = require("./package.json"); if (pkg.devDependencies && pkg.devDependencies.vite) { console.error("Error: vite must be in dependencies for production builds (see 912fb927)"); process.exit(1); }'

.PHONY: checkstyle-npm
checkstyle-npm: lint-npm tidy-npm check-audits-npm check-vite-deps ## Run JS lint, tidy and npm audits

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
