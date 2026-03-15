# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Structure

The repository contains two related projects:

### reqs-up (main project)
- **Location**: `/src/`
- **Purpose**: CLI utility to update semver versions in Ansible `requirements.yml` files
- **Language**: Crystal
- **Key files**:
  - `src/reqs-up.cr` - Core logic: parses requirements.yml, fetches git tags, updates versions
  - `src/main.cr` - CLI entry point with argument parsing

### ameba (code quality tool)
- **Location**: `/lib/ameba/src/`
- **Purpose**: Static code analyzer/linter for Crystal
- **Language**: Crystal
- **Package**: Managed via [shard.yml](lib/ameba/shard.yml)
- **Key files**:
  - `/lib/ameba/bin/ameba.cr` - Entry point for ameba binary
  - `/lib/ameba/src/ameba.cr` - Core ameba implementation

## Development Commands

### Build ameba binary
```bash
cd lib/ameba
make build
```

### Build reqs-up binary
```bash
crystal run src/reqs-up.cr
```

Or using Makefile in ameba (after installing reqs-up as dependency):
```bash
make build
```

### Run tests
- **ameba tests**: `make spec` (runs Crystal spec suite)
- **reqs-up tests**: Run `crystal spec` in root directory
- **ameba full test**: `make test` (runs specs + lint)

### Lint code
- **ameba on itself**: `make lint` (runs ameba binary on ameba codebase)
- **Lint reqs-up**: Run ameba against `src/` directory

## Architecture

### reqs-up flow
1. Parses `requirements.yml` (default: `./requirements.yml`)
2. For each entry with `scm: git`:
   - Runs `git ls-remote --tags --refs <url>` to fetch all tags
   - Parses version tags from output
3. Compares current version against latest using Semantic Versioning
4. Updates version based on `-P` (patch), `-M` (minor), or `-l` (latest)

### ameba flow
1. Reads `.ameba.yml` config (or generates via `ameba --gen-config`)
2. Applies glob patterns to include/exclude files
3. Runs all configured rules on matching Crystal files
4. Outputs issues with formatting options (dot, json, flycheck, etc.)
5. Supports `--fix` for auto-correction of marked issues

## Configuration

### .ameba.yml
Global configuration for ameba rules:
```yaml
Globs:
  - "**/*.cr"
  Excluded:
    - "!lib"
```

Rules can be enabled/disabled:
```yaml
Lint/UnusedArgument:
  Enabled: false
```

## Common Issues

- **Missing git**: reqs-up requires `git` executable
- **No tags**: `git ls-remote --tags` must return tags to update
- **Semantic Versioning**: Both projects use semver format
- **Crystal workers**: Performance improves with `CRYSTAL_WORKERS=8 ameba`

## GitHub Actions

CI runs tests on Ubuntu and macOS with Crystal latest and nightly:
- `lib/ameba/.github/workflows/ci.yml` - ameba CI
- `lib/ameba/.github/workflows/cd.yml` - deployment workflow
