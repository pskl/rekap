# Rekap

Rekap is a CLI utility to generate a PDF recap of your monthly activity on a repository as a contributor/contractor/maintainer.

Supports:

- local repositories
- GitHub repositories and associated Kanban boards

## Usage

### Obtain a personal GitHub access token (optional)

Settings > Developer settings (assign basic read rights)

### Install dependencies

`bundle install`

### Generate reports

**GitHub mode** (requires personal access token):

```bash
bundle exec ruby main.rb --project=user/repo --gh-token=XXXXXXX --output=/path/to/output
```

**Local mode** (uses local git repositories):

```bash
bundle exec ruby main.rb --repo1=/path/to/repo --email-author=you@example.com --output=/path/to/output
```

Optionally report on two repositories (if you worked on two repositories for instance):

```bash
bundle exec ruby main.rb --repo1=/path/to/repo1 --repo2=/path/to/repo2 --email-author=you@example.com
```
