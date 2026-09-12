.PHONY: setup run test clean

VENV := .venv
PYTHON := $(VENV)/bin/python
PIP := $(VENV)/bin/pip

setup:
	python3 -m venv $(VENV)
	$(PIP) install --upgrade pip
	$(PIP) install -e ".[dev]" 2>/dev/null || $(PIP) install -e .
	$(PIP) install pytest
	@command -v ffmpeg >/dev/null 2>&1 || echo "warning: ffmpeg not found on PATH — run: brew install ffmpeg"
	@echo ""
	@echo "Setup complete. Run: $(VENV)/bin/igdl <url>"

run:
	@if [ -z "$(URL)" ]; then echo "usage: make run URL=https://www.instagram.com/reel/..."; exit 1; fi
	$(VENV)/bin/igdl "$(URL)"

test:
	$(VENV)/bin/pytest -q

clean:
	rm -rf $(VENV) build dist *.egg-info
