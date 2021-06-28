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
