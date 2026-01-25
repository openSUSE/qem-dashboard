MOJO_MODE ?= production
TEST_ONLINE ?= postgresql://postgres:postgres@localhost:5432/postgres
HARNESS_PERL_SWITCHES ?= -MDevel::Cover=-ignore,^blib/,-ignore,^templates/,-ignore,Net/SSLeay,-ignore,Dashboard/Plugin/Database.pm
COVERAGE_OPTS ?= PERL5OPT='$(HARNESS_PERL_SWITCHES)'
TEST_WRAPPER_COVERAGE ?= 1
ASSET_SOURCES := $(shell find assets -type f) package-lock.json vite.config.js
COMMIT_ARGS ?= --last

.PHONY: all
all: help

.PHONY: help
help:
	@echo Call one of the available targets:
	@sed -n 's/^\([^.#[:space:]A-Z]*\):.*$$/\1/p' Makefile | uniq
	@echo See README.md for more details

.PHONY: install-deps-js
install-deps-js:
	npm clean-install --ignore-scripts
	npx playwright install --with-deps

.PHONY: install-deps-js-full
install-deps-js-full:
	npm install --ignore-scripts  # "npm clean-install" seems to not always build all assets. This is meant for development setups

.PHONY: install-deps-ubuntu
install-deps-ubuntu:
	sudo apt-get update
	sudo apt-get install -y libmagic-dev ruby-sass

.PHONY: install-deps-cpanm
install-deps-cpanm:
	cpanm -n --installdeps --with-feature=coverage .

.PHONY: install-deps
install-deps: install-deps-js install-deps-ubuntu install-deps-cpanm

.PHONY: build
build: public/asset

public/asset: $(ASSET_SOURCES)
	npm run build
	touch public/asset

.PHONY: start-postgres
start-postgres:
	podman run -p 5432:5432 -e POSTGRES_PASSWORD=postgres -d docker.io/library/postgres

.PHONY: run-mock
run-mock: build
	MOJO_MODE=development \
	TEST_ONLINE=$(TEST_ONLINE) \
	./script/run-mock

.PHONY: run-dashboard-local
.NOTPARALLEL: run-dashboard-local
run-dashboard-local: install-deps-js-full build
	git restore package-lock.json
	env DASHBOARD_CONF_OVERRIDE='{"pg":"${TEST_ONLINE}"}' script/dashboard daemon

.PHONY: run-mcp-stdio
run-mcp-stdio:
	./script/mcp-stdio

.PHONY: tidy-npm
tidy-npm:
	npm run lint:fix

.PHONY: tidy-perl
tidy-perl:
	bash -c 'shopt -s extglob globstar nullglob; perltidy --pro=.../.perltidyrc -b -bext='/' **/*.p[lm] **/*.t && git diff --exit-code'

.PHONY: tidy
tidy: tidy-npm tidy-perl

.PHONY: test-unit
test-unit: public/asset
	MOJO_MODE=$(MOJO_MODE) \
	TEST_ONLINE=$(TEST_ONLINE) \
	HARNESS_PERL_SWITCHES=$(HARNESS_PERL_SWITCHES) \
	prove -l t/*.t

.PHONY: test-ui
test-ui: public/asset
	MOJO_MODE=$(MOJO_MODE) \
	TEST_ONLINE=$(TEST_ONLINE) \
	TEST_WRAPPER_COVERAGE=$(TEST_WRAPPER_COVERAGE) \
	$(if $(TEST_WRAPPER_COVERAGE),$(COVERAGE_OPTS)) \
	prove -l t/*.t.js

.PHONY: test-js-unit
test-js-unit:  # Run JS unit tests
	npm run test:unit

.PHONY: check-audits-cpan
check-audits-cpan:
	PERL5LIB=~/perl5/lib/perl5:$$PERL5LIB PATH=~/perl5/bin:$$PATH cpan-audit deps . \
		--exclude CPANSA-Mojolicious-2024-58134 \
		--exclude CPANSA-Mojolicious-2024-58135 \
		--exclude CPANSA-File-Temp-2011-4116

.PHONY: check-audits-npm
check-audits-npm:
	npm audit

.PHONY: check-audits
check-audits: check-audits-cpan check-audits-npm  # Run audits

.PHONY: lint-npm
lint-npm:
	npm run lint
	npm run lint:commit -- $(COMMIT_ARGS)

.PHONY: checkstyle-perl
checkstyle-perl: tidy-perl check-audits-cpan

.PHONY: checkstyle-npm
checkstyle-npm: lint-npm tidy-npm check-audits-npm

.PHONY: checkstyle
checkstyle: checkstyle-perl checkstyle-npm

.PHONY: only-test
only-test: test-unit test-ui test-js-unit

.PHONY: test
test: checkstyle only-test

.PHONY: coverage
coverage: test
	cover

.PHONY: only-test-coverage
only-test-coverage: only-test
	./script/check-coverage

.PHONY: test-coverage
test-coverage: only-test-coverage checkstyle
