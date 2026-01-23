MOJO_MODE ?= production
TEST_ONLINE ?= postgresql://postgres:postgres@localhost:5432/postgres
HARNESS_PERL_SWITCHES ?= -MDevel::Cover=-ignore,^blib/,-ignore,^templates/,-ignore,Net/SSLeay
COVERAGE_OPTS ?= PERL5OPT='$(HARNESS_PERL_SWITCHES)'
TEST_WRAPPER_COVERAGE ?= 1
ASSET_SOURCES := $(shell find assets -type f) package-lock.json webpack.config.js

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

.PHONY: install-deps-ubuntu
install-deps-ubuntu:
	sudo apt-get update
	sudo apt-get install -y libmagic-dev ruby-sass

.PHONY: install-deps-cpanm
install-deps-cpanm:
	cpanm -n --installdeps .
	cpanm -n Test::Deep
	cpanm -n Devel::Cover::Report::Coveralls

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
run-mock:
	MOJO_MODE=$(MOJO_MODE) \
	TEST_ONLINE=$(TEST_ONLINE) \
	./script/run-mock

.PHONY: tidy-js
tidy-js:
	npm run lint:fix

.PHONY: tidy-perl
tidy-perl:
	bash -c 'shopt -s extglob globstar nullglob; perltidy --pro=.../.perltidyrc -b -bext='/' **/*.p[lm] **/*.t && git diff --exit-code'

.PHONY: tidy
tidy: tidy-js tidy-perl

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

.PHONY: lint-js
lint-js:
	npm run lint

.PHONY: checkstyle
checkstyle: tidy lint-js

.PHONY: only-test
only-test: test-unit test-ui

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
