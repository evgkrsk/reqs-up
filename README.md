# reqs-up
Simple CLI utility to update semver versions in ansible's
requirements.yml files.

It tries to fetch remote url (only git supported at moment) and bump
up version to latest one.

It is assumed that all urls is accesible or public (i.e. may be view
by "git ls-remote" without manual authentication).

Note: all comments in YAML will be LOST (PR-s welcome)!

# Examples

```bash
# reqs-up -f ./requirements.yaml
```
- update 'requirements.yaml' file in-place, bumping up versions

```bash
# reqs-up --dry-run
```
- dry-run, print new version of YAML doc on stdout.
  requirements.yml assumed in current working dir.

```bash
# reqs-up --minor
```
- update only within minor version (same major). Example: 1.2.3 -> 1.9.5 (but not 2.0.0)

```bash
# reqs-up --patch
```
- update only within patch version (same major and minor). Example: 1.2.3 -> 1.2.8 (but not 1.3.0)

# Output

When updating, the tool shows the old version, new version, and explanation:

```
ansible-role-1: 1.2.3 → 1.2.8 (max patch version for 1.2.x)
ansible-role-2: 1.2.3 → 1.9.5 (max minor version for 1.x)
ansible-role-3: 1.2.3 → 2.1.0 (latest)
```

# Options

- `-f FILE`, `--file=FILE` - Specifies the requirements file (default: ./requirements.yml)
- `-n`, `--dry-run` - Output result YAML to stdout instead of writing to file
- `-m`, `--minor` - Update only within minor version (same major)
- `-p`, `--patch` - Update only within patch version (same major and minor)
- `-h`, `--help` - Show help and exit
- `-v`, `--version` - Print version and exit

Note: `--minor` and `--patch` are mutually exclusive.

# Changelog

See [CHANGELOG.md](./CHANGELOG.md) for details.
