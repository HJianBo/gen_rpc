#
# Based on the concrete.mk project at https://github.com/chef/concrete
# Original work is licensed under the Apache license
# Copyright, 2013 Opscode Inc.
#
# Default targets for all Erlang projects are:
#
# all: 			Default target. Runs rebar3 compile
# clean: 		Runs rebar3 clean
# distclean: 	Runs rebar3 clean -a and removes the _build and log directory
# test: 		Runs rebar3 ct
# dialyzer: 	Runs rebar3 dialyzer
# typer: 		Runs typer to generate source code specs
# xref:			Runs rebar3 xref
# rebar: 		Downloads a precompiled rebar3 binary and places it inside the project. The rebar binary is .gitignored.
#				This step is always run first on build targets.
# dist: 		Runs all test dialyzer. This should be ran by a CI system or a pre-commit hook to ensure code correctness.
#
# Helper targets defined here are:
#
# shell:		Starts a simple Erlang shell with the application's binaries included
# tags:			Builds Emacs tags file

.DEFAULT_GOAL := all

.PHONY: all compile dist clean distclean testclean test ct dialyzer epmd rebar shell tags xref typer

# =============================================================================
# verify that the programs we need to run are installed on this system
# =============================================================================
ERL = $(shell which erl)

ifeq ($(ERL),)
$(error "Erlang not available on this system")
endif

# If there is a rebar in the current directory, use it
ifeq ($(wildcard rebar3),rebar3)
REBAR = $(CURDIR)/rebar3
endif

# And finally, prep to download rebar if all else fails
ifeq ($(REBAR),)
REBAR = $(CURDIR)/rebar3
endif

DIALYZER = dialyzer
DIALYZER_OPTS = -Wno_return -Wno_unused -Wno_improper_lists -Wno_fun_app -Wno_match -Wno_opaque -Wno_fail_call -Wno_contracts -Wno_behaviours -Wno_undefined_callbacks -Wunmatched_returns -Werror_handling -Wrace_conditions -Woverspecs -Wunderspecs -Wspecdiffs
DIALYZER_APPS = asn1 compiler common_test crypto edoc erts eunit inets kernel mnesia public_key ssl stdlib syntax_tools tools xmerl
BASE_PLT = $(HOME)/.cache/rebar3/base.plt

REBAR_URL = https://s3.amazonaws.com/rebar3/rebar3
TYPER_OPTS = --annotate --annotate-inc-files -I ./include
PROJ ?= $(notdir $(CURDIR))

# =============================================================================
# Main targets
# =============================================================================

all: $(REBAR)
	@$(REBAR) compile

compile: all

dist: all test dialyzer

# =============================================================================
# Clean targets
# =============================================================================

# Clean ebin and .eunit of this project
clean:
	@$(REBAR) clean

# Full clean and removal of all build artifacts. Remove deps first to avoid
# wasted effort of cleaning deps before nuking them.
distclean: clean
	@rm -rf _build log .rebar ebin/ $(PROJ).plt
	@find . -name erl_crash.dump -type f -delete

testclean:
	@find log/ct -maxdepth 1 -name ct_run* -type d -cmin +360 -exec rm -fr {} \;

# =============================================================================
# Test targets
# =============================================================================

test: ct

ct: epmd
	@$(REBAR) as test do ct

dialyzer: $(BASE_PLT)
	@$(REBAR) as test do dialyzer || true
	@$(DIALYZER) $(DIALYZER_OPTS) --plts $(CURDIR)/$(PROJ).plt -r _build/test/lib/$(PROJ)/ebin

# =============================================================================
# Misc targets
# =============================================================================

# Run epmd to allow Distributed Erlang to run during tests
epmd:
	@pgrep -q epmd || epmd -daemon || true

$(REBAR):
	curl -Lo rebar3 $(REBAR_URL) || wget $(REBAR_URL)
	chmod a+x rebar3

rebar: $(REBAR)

$(BASE_PLT):
	@$(DIALYZER) --build_plt --apps $(DIALYZER_APPS) --output_plt $(BASE_PLT);

shell: epmd
	@$(REBAR) shell

tags:
	find src _build/default/lib -name "*.[he]rl" -print | etags -

xref:
	@$(REBAR) xref

typer: dialyzer
	@$(TYPER) $(TYPER_OPTS) --plt $(PROJ).plt -r src/