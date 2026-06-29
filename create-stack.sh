#!/usr/bin/env bash
#
# create-stack.sh — Build a 3-layer stacked-PR chain with Aviator (av).
#
# Reproduces the remote pattern: main -> <prefix>-1 -> <prefix>-2 -> <prefix>-3,
# where each layer appends one line to README.md and opens its own PR.
#
# Usage:
#   ./create-stack.sh            # uses default prefix "a"  -> a-1 / a-2 / a-3
#   ./create-stack.sh demo       # custom prefix            -> demo-1 / demo-2 / demo-3
#
set -euo pipefail

PREFIX="${1:-a}"   # branch/commit/PR name prefix
LAYERS=3           # number of stacked branches
TRUNK="main"       # trunk branch
FILE="README.md"   # file each layer modifies

# Always operate from the repo root.
cd "$(git rev-parse --show-toplevel)"

# av must be initialized for this repo.
if [ ! -f "$(git rev-parse --git-common-dir)/av/av.db" ]; then
  echo "Error: av is not initialized. Run 'av init' first." >&2
  exit 1
fi

# Working tree must be clean (untracked files are fine); otherwise git pull and
# av commit would pick up unrelated changes.
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Error: working tree has uncommitted changes. Commit or 'git restore' them first." >&2
  exit 1
fi

# Refuse to clobber existing branches from a previous run.
for i in $(seq 1 "$LAYERS"); do
  name="${PREFIX}-${i}"
  if git show-ref --verify --quiet "refs/heads/${name}"; then
    echo "Error: branch '${name}' already exists. Delete it or use another prefix." >&2
    exit 1
  fi
done

# Start from an up-to-date trunk.
git checkout "$TRUNK"
git pull --ff-only origin "$TRUNK"

# Build the stack: each layer is branched on top of the previous one.
for i in $(seq 1 "$LAYERS"); do
  name="${PREFIX}-${i}"
  av branch "$name"                        # create + switch to a branch stacked on current
  echo "$name" >> "$FILE"                  # one-line change per layer
  av commit -a -m "$name"                  # stage tracked changes, commit, auto-restack
done

# Push every branch and open all PRs at once. EDITOR=true makes the PR editor a
# no-op (exits 0 immediately), so av uses its default title/body without
# prompting — keeps the script non-interactive.
EDITOR=true av pr --all

echo "Done. Created ${LAYERS}-layer stack: ${PREFIX}-1 -> ${PREFIX}-2 -> ${PREFIX}-3"
