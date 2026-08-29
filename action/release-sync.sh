#!/usr/bin/env bash
set -euo pipefail

: "${TARGET_REPO:?TARGET_REPO is required}"
TARGET_BRANCH="${TARGET_BRANCH:-main}"
IGNORE_FILE="${IGNORE_FILE:-.syncignore}"
ENV_FILE="${ENV_FILE:-.env}"
VERSION_KEY="${VERSION_KEY:-APP_VERSION}"
BOT_NAME="${BOT_NAME:-release-sync-bot}"
BOT_EMAIL="${BOT_EMAIL:-release-sync-bot@users.noreply.github.com}"

WORKDIR="$(mktemp -d)"
SNAPSHOT="$WORKDIR/snapshot"
TARGET="$WORKDIR/target"
mkdir -p "$SNAPSHOT"

echo "==> Extracting version from ${ENV_FILE} (${VERSION_KEY})"
if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: ${ENV_FILE} not found" >&2
  exit 1
fi
VERSION=$(grep -E "^${VERSION_KEY}=" "$ENV_FILE" | head -n1 | cut -d '=' -f2- | tr -d '"'"'"'\r')
if [ -z "$VERSION" ]; then
  echo "ERROR: ${VERSION_KEY} not found or empty in ${ENV_FILE}" >&2
  exit 1
fi
if ! [[ "$VERSION" =~ ^[0-9A-Za-z][0-9A-Za-z.+-]*$ ]]; then
  echo "ERROR: version '${VERSION}' doesn't look like a safe tag name" >&2
  exit 1
fi
TAG="v${VERSION}"
echo "==> Version resolved: ${VERSION} (tag: ${TAG})"

echo "==> Building filtered snapshot (excluding via ${IGNORE_FILE})"
RSYNC_EXCLUDES=(--exclude='.git' --exclude="$IGNORE_FILE")
if [ -f "$IGNORE_FILE" ]; then
  RSYNC_EXCLUDES+=(--exclude-from="$IGNORE_FILE")
else
  echo "WARNING: ${IGNORE_FILE} not found — nothing will be excluded"
fi
rsync -a "${RSYNC_EXCLUDES[@]}" ./ "$SNAPSHOT/"

echo "==> Cloning target repo ${TARGET_REPO} (branch: ${TARGET_BRANCH})"
if git clone --branch "$TARGET_BRANCH" --single-branch --depth 1 "$TARGET_REPO" "$TARGET" 2>/dev/null; then
  echo "==> Existing branch ${TARGET_BRANCH} found"
else
  echo "==> Branch ${TARGET_BRANCH} not found — initializing it as an orphan branch"
  git clone --depth 1 "$TARGET_REPO" "$TARGET"
  (cd "$TARGET" && git checkout --orphan "$TARGET_BRANCH" && git rm -rf . >/dev/null 2>&1 || true)
fi

cd "$TARGET"
git config user.name "$BOT_NAME"
git config user.email "$BOT_EMAIL"

if git rev-parse "refs/tags/${TAG}" >/dev/null 2>&1; then
  echo "ERROR: tag ${TAG} already exists on the target repo — refusing to overwrite" >&2
  exit 1
fi

echo "==> Replacing tree contents (keeping target repo's own commit history)"
rsync -a --delete --exclude='.git' "$SNAPSHOT/" ./

git add -A
if git diff --cached --quiet; then
  echo "==> No file changes detected — tagging current HEAD as-is"
else
  git commit -m "Release ${TAG} (source ${GITHUB_REPOSITORY:-unknown}@${GITHUB_SHA:-unknown})"
fi

git tag -a "$TAG" -m "Release ${TAG}"

echo "==> Pushing branch and tag (non-force)"
git push origin "HEAD:${TARGET_BRANCH}"
git push origin "$TAG"

echo "==> Done: pushed ${TAG} to ${TARGET_REPO}#${TARGET_BRANCH}"
