.PHONY: all
all: help

.PHONY: help
help:
	@echo Call one of the available targets:
	@sed -n 's/\(^[^.#[:space:]A-Z]*\):.*$$/\1/p' Makefile | uniq
	@echo See README.md for more details

.PHONY: install-deps-js
install-deps-js:
	npm install --ignore-scripts
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

.PHONY: test-unit
test-unit:
	MOJO_MODE=production \
	TEST_ONLINE=postgresql://postgres:postgres@localhost:5432/postgres \
	HARNESS_PERL_SWITCHES=-MDevel::Cover \
	prove -l t/*.t

.PHONY: test-ui
test-ui:
	MOJO_MODE=production \
	TEST_ONLINE=postgresql://postgres:postgres@localhost:5432/postgres \
	TEST_WRAPPER_COVERAGE=1 \
	prove -l -v t/*.t.js

.PHONY: test
test: test-unit test-ui
