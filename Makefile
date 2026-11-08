LUA ?= lua
LUAC ?= luac
PYTHON ?= python3

.PHONY: check test package

check:
	$(LUAC) -p TeamfitTactics/Quest.lua TeamfitTactics/Tracker.lua TeamfitTactics/Addon.lua tests/run.lua

test:
	$(LUA) tests/run.lua

package:
	$(PYTHON) scripts/package.py

