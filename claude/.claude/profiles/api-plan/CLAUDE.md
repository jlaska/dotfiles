# Python Package Management with uv

Use uv exclusively for Python package management.

## Package Management Commands

- Install dependencies: `uv add <package>`
- Remove dependencies: `uv remove <package>`
- Sync environment: `uv sync`
- Lock dependencies: `uv lock`
- Never use pip, pip-tools, poetry, or conda directly

## Running Python Code

- Run scripts: `uv run script.py`
- Run tools: `uv run pytest`, `uv run ruff`, `uv run mypy`
- Run Python REPL: `uv run python`
- Run standalone scripts with inline deps: `uv run --with <pkg> script.py`
- Run one-off tools without installing: `uvx <tool>`

## Scripts with PEP 723 Inline Metadata

- Add dependency to script: `uv add <package> --script script.py`
- Remove dependency: `uv remove <package> --script script.py`
