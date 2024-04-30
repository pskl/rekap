# Rekap

Rekap is a CLI utility to generate a PDF recap of your monthly GitHub activity on a repository as a contractor.

## Usage

### Obtain a personal access token

Settings > Developer settings (assign basic read rights)

### Install dependencies

`bundle install`

### Generate reports

```bash
bundle exec ruby main.rb --project=user/repo --gh-token=XXXXXXX --output=/path/to/output
```
