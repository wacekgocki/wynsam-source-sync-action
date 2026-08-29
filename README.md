# Wynsam Source Sync Action

Automated GitHub Action tooling to synchronize filtered release snapshots from a source repository to a target customer repository without sharing internal git history.

## Overview

Action extracts a clean release snapshot from a source repository branch (e.g., `release`), filters out internal or sensitive files using rules defined in [.syncignore](.syncignore), extracts the version string from a configuration file, tags the release (`vX.Y.Z`), and pushes the snapshot to a target repository branch (`main`).

## Key Features

- **Filtered Sync**: Excludes internal directories, tests, and configuration files via `rsync` rules in [.syncignore](.syncignore).
- **Automatic Tagging**: Resolves release version from `APP_VERSION` in the environment file and tags target releases (`vX.Y.Z`).
- **History Isolation**: Keeps customer repositories clean and isolated from internal commit history while preserving target repository commit history.
- **Secure Authentication**: Uses dedicated SSH deploy keypairs per repository pair.

## Repository Contents

- [action/action.yml](action/action.yml): Composite GitHub Action definition.
- [action/release-sync.sh](action/release-sync.sh): Synchronization script handling snapshotting, rsync filtering, and git operations.
- [release-sync.yml](release-sync.yml): Example workflow template for source repositories.
- [.syncignore](.syncignore): Exclude-list template for snapshot filtering.
- [RECIPE.md](RECIPE.md): Complete setup and operational recipe.

## Action Inputs

| Input | Description | Required | Default |
| --- | --- | --- | --- |
| `target_repo` | SSH clone URL of target repository | Yes | N/A |
| `target_branch` | Branch on target repository to publish to | No | `main` |
| `deploy_key` | SSH private deploy key for target repository | Yes | N/A |
| `ignore_file` | Path to exclude patterns file | No | `.syncignore` |
| `env_file` | Path to environment file containing version | No | `.env` |
| `version_key` | Key name holding version string | No | `APP_VERSION` |
| `bot_name` | Git commit author name | No | `release-sync-bot` |
| `bot_email` | Git commit author email | No | `release-sync-bot@users.noreply.github.com` |

## Important Note

The repository that contains this action must be public when you reference it as `uses: your-org/release-sync-action@v1`. GitHub Actions cannot use a private personal-account repository this way, and a private repo requires a different setup pattern.

## Quick Start

In your source repository, configure `.github/workflows/release-sync.yml`:

```yaml
name: Release Sync

on:
  push:
    branches: [release]

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Sync release to customer repo
        uses: your-org/release-sync-action@v1
        with:
          target_repo: git@github.com:customer-org/target-repo.git
          deploy_key: ${{ secrets.RELEASE_SYNC_DEPLOY_KEY }}
```

Refer to [RECIPE.md](RECIPE.md) for full setup instructions, deploy key generation, and notification setup.
