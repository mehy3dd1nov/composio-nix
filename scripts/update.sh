#!/usr/bin/env bash
set -euo pipefail

REPO="ComposioHQ/composio"

# Auto-detect channel from argument or current git branch
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "stable")
CHANNEL="${1:-}"
if [ -z "${CHANNEL}" ]; then
  if [ "${CURRENT_BRANCH}" = "unstable" ] || [ "${CURRENT_BRANCH}" = "beta" ]; then
    CHANNEL="beta"
  else
    CHANNEL="stable"
  fi
fi

echo "Checking for latest ${CHANNEL} @composio/cli releases from ${REPO} (branch: ${CURRENT_BRANCH})..."

AUTH_HEADER=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
  AUTH_HEADER=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

if [ "${CHANNEL}" = "stable" ]; then
  LATEST_TAG=$(curl -sL "${AUTH_HEADER[@]}" "https://api.github.com/repos/${REPO}/releases?per_page=100" | jq -r 'sort_by(.published_at) | reverse | .[].tag_name' | grep -E '^@composio/cli@[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1)
else
  LATEST_TAG=$(curl -sL "${AUTH_HEADER[@]}" "https://api.github.com/repos/${REPO}/releases?per_page=100" | jq -r 'sort_by(.published_at) | reverse | .[].tag_name' | grep -E '^@composio/cli@' | head -n 1)
fi

if [ -z "${LATEST_TAG}" ] || [ "${LATEST_TAG}" = "null" ]; then
  echo "Error: Could not retrieve release tag for @composio/cli (${CHANNEL})"
  exit 1
fi

VERSION="${LATEST_TAG#@composio/cli@}"
CURRENT_VERSION=$(grep -o 'version = "[^"]*"' package.nix | head -n 1 | cut -d '"' -f 2)

echo "Current version in package.nix: ${CURRENT_VERSION}"
echo "Target upstream release tag:    ${VERSION} (${CHANNEL})"

if [ "${CURRENT_VERSION}" = "${VERSION}" ]; then
  echo "Repository is already up to date with upstream ${CHANNEL}."
  exit 0
fi

echo "Updating package.nix to ${VERSION}..."
BASE_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}"

fetch_hash() {
  local asset="$1"
  nix store prefetch-file "${BASE_URL}/${asset}" --json | jq -r .hash
}

echo "Prefetching hashes for ${VERSION}..."
HASH_X86_64_LINUX=$(fetch_hash "composio-linux-x64.zip")
HASH_AARCH64_LINUX=$(fetch_hash "composio-linux-aarch64.zip")
# x86_64-darwin is excluded: dropped in Nixpkgs 26.11 (nix-porter §3.5)
HASH_AARCH64_DARWIN=$(fetch_hash "composio-darwin-aarch64.zip")

echo "x86_64-linux:   ${HASH_X86_64_LINUX}"
echo "aarch64-linux:  ${HASH_AARCH64_LINUX}"
echo "aarch64-darwin: ${HASH_AARCH64_DARWIN}"

# Update version
sed -i "s/version = \"${CURRENT_VERSION}\"/version = \"${VERSION}\"/" package.nix

# Update hashes using ranged sed
sed -i "/x86_64-linux = {/,/};/ s|hash = \"[^\"]*\";|hash = \"${HASH_X86_64_LINUX}\";|" package.nix
sed -i "/aarch64-linux = {/,/};/ s|hash = \"[^\"]*\";|hash = \"${HASH_AARCH64_LINUX}\";|" package.nix
sed -i "/aarch64-darwin = {/,/};/ s|hash = \"[^\"]*\";|hash = \"${HASH_AARCH64_DARWIN}\";|" package.nix

# Also update skill if changed
echo "Updating skills from composio-skill.zip..."
TMP_SKILL=$(mktemp -d)
curl -sL "${BASE_URL}/composio-skill.zip" -o "${TMP_SKILL}/skill.zip"
unzip -q -o "${TMP_SKILL}/skill.zip" -d skills/ || true
rm -rf "${TMP_SKILL}"

echo "Done. package.nix and skills updated to ${VERSION} (${CHANNEL})."
