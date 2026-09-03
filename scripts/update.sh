#!/usr/bin/env bash
set -euo pipefail

REPO="ComposioHQ/composio"

echo "Checking for latest @composio/cli releases from ${REPO}..."
LATEST_TAG=$(curl -s "https://api.github.com/repos/${REPO}/releases" | grep -o '"tag_name": *"@composio/cli@[^"]*"' | head -n 1 | cut -d '"' -f 4)

if [ -z "${LATEST_TAG}" ]; then
  echo "Error: Could not retrieve release tag for @composio/cli"
  exit 1
fi

VERSION="${LATEST_TAG#@composio/cli@}"
CURRENT_VERSION=$(grep -o 'version = "[^"]*"' package.nix | head -n 1 | cut -d '"' -f 2)

echo "Current version in package.nix: ${CURRENT_VERSION}"
echo "Latest upstream release tag:    ${VERSION}"

if [ "${CURRENT_VERSION}" = "${VERSION}" ]; then
  echo "Repository is already up to date with upstream."
  exit 0
fi

echo "Updating package.nix to ${VERSION}..."
BASE_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}"

fetch_hash() {
  local asset="$1"
  nix store prefetch-file "${BASE_URL}/${asset}" --json | grep -o '"hash": *"[^"]*"' | cut -d '"' -f 4
}

echo "Prefetching hashes for ${VERSION}..."
HASH_X86_64_LINUX=$(fetch_hash "composio-linux-x64.zip")
HASH_AARCH64_LINUX=$(fetch_hash "composio-linux-aarch64.zip")
HASH_X86_64_DARWIN=$(fetch_hash "composio-darwin-x64.zip")
HASH_AARCH64_DARWIN=$(fetch_hash "composio-darwin-aarch64.zip")

echo "x86_64-linux:   ${HASH_X86_64_LINUX}"
echo "aarch64-linux:  ${HASH_AARCH64_LINUX}"
echo "x86_64-darwin:  ${HASH_X86_64_DARWIN}"
echo "aarch64-darwin: ${HASH_AARCH64_DARWIN}"

# Update version
sed -i "s/version = \"${CURRENT_VERSION}\"/version = \"${VERSION}\"/" package.nix

# Update hashes using ranged sed
sed -i "/x86_64-linux = {/,/};/ s|hash = \"[^\"]*\";|hash = \"${HASH_X86_64_LINUX}\";|" package.nix
sed -i "/aarch64-linux = {/,/};/ s|hash = \"[^\"]*\";|hash = \"${HASH_AARCH64_LINUX}\";|" package.nix
sed -i "/x86_64-darwin = {/,/};/ s|hash = \"[^\"]*\";|hash = \"${HASH_X86_64_DARWIN}\";|" package.nix
sed -i "/aarch64-darwin = {/,/};/ s|hash = \"[^\"]*\";|hash = \"${HASH_AARCH64_DARWIN}\";|" package.nix

# Also update skill if changed
echo "Updating skills from composio-skill.zip..."
TMP_SKILL=$(mktemp -d)
curl -sL "${BASE_URL}/composio-skill.zip" -o "${TMP_SKILL}/skill.zip"
unzip -q -o "${TMP_SKILL}/skill.zip" -d skills/ || true
rm -rf "${TMP_SKILL}"

echo "Done. package.nix and skills updated to ${VERSION}."
