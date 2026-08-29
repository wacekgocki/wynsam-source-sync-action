# Wynsam Source Sync

Automated GitHub Action tooling to synchronize filtered release snapshots from a source repository to a target customer repository without sharing internal git history.

## Overview

Wynsam Source Sync extracts a clean release snapshot from a source repository branch (e.g., `release`), filters out internal or sensitive files using rules defined in [wynsam-source-sync/.syncignore](wynsam-source-sync/.syncignore), extracts the version string from a configuration file, tags the release (`vX.Y.Z`), and pushes the snapshot to a target repository branch (`main`).

## Key Features

- **Filtered Sync**: Excludes internal directories, tests, and configuration files via `rsync` rules in [wynsam-source-sync/.syncignore](wynsam-source-sync/.syncignore).
- **Automatic Tagging**: Resolves release version from `APP_VERSION` in the environment file and tags target releases (`vX.Y.Z`).
- **History Isolation**: Keeps customer repositories clean and isolated from internal commit history while preserving target repository commit history.
- **Secure Authentication**: Uses dedicated SSH deploy keypairs per repository pair.

## Repository Contents

- [wynsam-source-sync/action/action.yml](wynsam-source-sync/action/action.yml): Composite GitHub Action definition.
- [wynsam-source-sync/action/release-sync.sh](wynsam-source-sync/action/release-sync.sh): Synchronization script handling snapshotting, rsync filtering, and git operations.
- [wynsam-source-sync/release-sync.yml](wynsam-source-sync/release-sync.yml): Example workflow template for source repositories.
- [wynsam-source-sync/.syncignore](wynsam-source-sync/.syncignore): Exclude-list template for snapshot filtering.
- [wynsam-source-sync/RECIPE.md](wynsam-source-sync/RECIPE.md): Complete setup and operational recipe.

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

Refer to [wynsam-source-sync/RECIPE.md](wynsam-source-sync/RECIPE.md) for full setup instructions, deploy key generation, and notification setup.
