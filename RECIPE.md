# Release Sync — Implementation Recipe

Copies a filtered snapshot of `release` in one of your repos to `main` in a
corresponding customer repo, tags it with the version from `.env`, and
alerts by email on failure. Designed to be set up once and repeated for
every additional repo pair.

## Components

- **`your-org/release-sync-action`** — a shared tooling repo containing
  `action.yml` + `release-sync.sh`. This is the only place the actual logic
  lives. (Files: `action/action.yml`, `action/release-sync.sh`.)
- **A caller workflow** in each source repo, `.github/workflows/release-sync.yml`,
  a few lines that just point at the shared action. (File:
  `release-sync.yml`.)
- **A `.syncignore`** file in each source repo listing what never leaves it.
  (File: `.syncignore`.)
- **One SSH deploy keypair per repo pair** — never reused across repos.

---

## 0. One-time setup

1. Create `your-org/release-sync-action` (can be private, your own account/org).
2. Copy `action/action.yml` and `action/release-sync.sh` into it, commit,
   push, then tag a release: `git tag v1 && git push origin v1`. Caller
   workflows reference `your-org/release-sync-action@v1`.
3. Decide how alert emails get sent (e.g. an SMTP relay, a Gmail app
   password, or a transactional provider like SendGrid). You'll need
   `SMTP_USERNAME` / `SMTP_PASSWORD` and a recipient address — these can be
   org-level secrets if all your source repos are in one GitHub org, so you
   don't re-enter them per repo.

## Per repo pair (repeat this whole section for every repo you mirror)

### A. On the customer's GitHub (needs your temporary owner-like access)

1. **Create the repo**:
   `gh repo create customer-org/REPO-NAME --private --confirm`
   (or via the UI — initialize with a README so `main` exists as the
   default branch).
2. **Generate a dedicated keypair** for this repo pair only:
   `ssh-keygen -t ed25519 -f ./keys/REPO-NAME-deploy -C "release-sync:REPO-NAME" -N ""`
3. **Add the public key as a deploy key**: customer repo → Settings →
   Deploy keys → Add deploy key → paste `REPO-NAME-deploy.pub` → check
   **"Allow write access"** → Add key.
4. **Branch protection on `main`**: if you turn on any protection, do
   *not* require pull requests for merging — the bot pushes directly, not
   through a PR, and a PR requirement would block it. A tag-protection
   rule for `v*` (stops anyone deleting release tags) is a reasonable
   addition and doesn't interfere.
5. Note the SSH clone URL — `git@github.com:customer-org/REPO-NAME.git` —
   this is `target_repo` in the next section.
6. Repeat 1–5 for each repo. Keep the private keys in a temporary local
   folder; they get consumed and deleted in step B.4.

### B. On your side (the source repo being copied from)

1. Copy `.syncignore` into the repo root and edit it —
   list every file/dir that must not reach the customer.
2. Confirm `.env` at repo root has `APP_VERSION=x.y.z` (or pass different
   `env_file` / `version_key` inputs if it's named/located differently).
3. Copy `release-sync.yml` to
   `.github/workflows/release-sync.yml`, and set `target_repo` to this
   repo's customer URL from A.5.
4. Add the secret: repo Settings → Secrets and variables → Actions → New
   repository secret → name `RELEASE_SYNC_DEPLOY_KEY` → paste the private
   key from A.2. Securely delete the local private key file afterward.
5. If not already set at the org level, add `SMTP_USERNAME`,
   `SMTP_PASSWORD`, `ALERT_EMAIL_TO` as repo secrets.
6. Add `.github/` to this repo's own `.syncignore` if you don't want your
   CI internals visible in the customer's copy (usually yes).
7. Commit and push these changes to your default branch (not `release` —
   this is setup, not a release trigger).

### C. Test it

1. Bump `APP_VERSION` in `.env` on a local `release` branch, commit, then
   `git push origin release`.
2. Watch the Action run in your source repo.
3. Check the customer repo: `main` has the filtered tree, one new sync
   commit (their own prior history intact), and a matching `vX.Y.Z` tag.
4. Deliberately break something once (e.g. temporarily rename `.env`) to
   confirm the failure email arrives, then revert.

### D. Revoke your temporary access

Once every repo pair is set up and tested, your elevated access to the
customer's GitHub account/org can be removed. Nothing in the pipeline
depends on it going forward — each repo's deploy key is self-contained and
keeps working independently.

### E. Adding repo N+1 later

Only repeat sections A and B. The shared `release-sync-action` tooling
repo never changes for a new repo pair.

---

## Notes / gotchas

- **Non-force push**: the script replaces the file tree in a new commit on
  top of the customer's existing history rather than force-pushing —
  their commit log is preserved, and the deploy key only ever needs
  ordinary write access, not force-push rights.
- **First run on an empty repo**: the script detects a missing target
  branch and creates it as an orphan branch automatically — you don't
  need to pre-seed `main` with any particular content in step A.1 beyond
  what `gh repo create` gives you.
- **Duplicate version tags**: the script refuses to run if `vX.Y.Z` already
  exists on the target — bump `APP_VERSION` before re-triggering.
- **rsync exclude syntax** in `.syncignore` is close to but not identical
  to `.gitignore` syntax (no implicit `**` recursion on bare names in all
  cases) — test patterns against a repo you don't mind clobbering first.
