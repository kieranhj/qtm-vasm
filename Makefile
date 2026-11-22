# Wrapper so that `make` works from PowerShell / Windows Terminal.
# GNU make runs recipes with cmd.exe here (no sh on PATH).
# build.py regenerates src\ from ref\ and verifies each variant byte-for-byte.
PYTHON = python
.PHONY: all build check help
all: build

build:
	$(PYTHON) build.py

check:
	$(PYTHON) build.py --check

help:
	@echo make         - regenerate src\ and build + verify all four variants (build\qtm-*.bin)
	@echo make check   - verify without regenerating
	@echo make help    - this list
	@echo See START_HERE.md and README.md
