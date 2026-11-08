LUA ?= lua
LUAC ?= luac
PYTHON ?= python3

.PHONY: check test package

check:
	$(LUAC) -p TeamfitTactics/Addon.lua legacy/Quest.lua legacy/Tracker.lua tests/run.lua spikes/live-ingress/Probe.lua spikes/live-ingress/tests/probe_test.lua

test:
	$(LUA) tests/run.lua
	$(LUA) spikes/live-ingress/tests/probe_test.lua
	$(PYTHON) -m unittest discover -s spikes/live-ingress/tests -p 'test_*.py'

package:
	$(PYTHON) scripts/package.py
