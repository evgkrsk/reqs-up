# reqs-up
Simple CLI utility to update semver versions in ansible's
requirements.yaml files.

It tries to fetch remote url (only git supported at moment) and bump
up version to latest one.

It is assumed that all urls is accesible or public (i.e. may be view
by "git ls-remote" without manual authentication).

Note: all comments in YAML will be LOST (PR-s welcome)!

# Examples

```bash
# reqs-up -f ./requirements.yml
```
- update 'requirements.yml' file in-place, bumping up versions

```bash
# reqs-up --dry-run
```
- dry-run, print new version of YAML doc on stdout.
  requirements.yaml assumed in current working dir.
