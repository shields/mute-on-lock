#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
cd "$(dirname "$0")/.."
source tools/release-lib.sh
require_release_context
read_metadata
expected_hash=$(jq --exit-status --raw-output '.executableSHA256' dist/release.json)
[[ $(shasum -a 256 dist/mute-on-lock | awk '{print $1}') == "$expected_hash" ]] || die "Signed artifact checksum mismatch"
chmod +x dist/mute-on-lock
brew tap shields/tap
tap_directory=$(brew --repository shields/tap)
mkdir -p "$tap_directory/Formula"
cp dist/mute-on-lock.rb "$tap_directory/Formula/mute-on-lock.rb"
brew style "$tap_directory/Formula/mute-on-lock.rb"
brew install --build-bottle shields/tap/mute-on-lock
installed_binary=$(brew --prefix shields/tap/mute-on-lock)/bin/mute-on-lock
rm "$installed_binary"
cp -p dist/mute-on-lock "$installed_binary"
codesign --verify --strict --verbose=2 "$installed_binary"
cd dist
brew bottle --json --root-url "https://github.com/$release_repo/releases/download/$release_tag" shields/tap/mute-on-lock
bottle_json=mute-on-lock--$release_version.arm64_golden_gate.bottle.json
jq --exit-status '.["shields/tap/mute-on-lock"].bottle.cellar == "any_skip_relocation"' "$bottle_json"
bottle_filename=$(jq --exit-status --raw-output '.["shields/tap/mute-on-lock"].bottle.tags.arm64_golden_gate.filename' "$bottle_json")
[[ $bottle_filename == "mute-on-lock-$release_version.arm64_golden_gate.bottle.tar.gz" ]] || die "Unexpected bottle filename"
brew bottle --merge --write --no-commit "$bottle_json"
mv "mute-on-lock--$release_version.arm64_golden_gate.bottle.tar.gz" "$bottle_filename"
cp "$tap_directory/Formula/mute-on-lock.rb" mute-on-lock.rb
brew uninstall shields/tap/mute-on-lock
bottle_cache=$(brew --cache --bottle shields/tap/mute-on-lock)
mkdir -p "$(dirname "$bottle_cache")"
cp "$bottle_filename" "$bottle_cache"
brew install --force-bottle shields/tap/mute-on-lock
installed_binary=$(brew --prefix shields/tap/mute-on-lock)/bin/mute-on-lock
[[ $(shasum -a 256 "$installed_binary" | awk '{print $1}') == "$expected_hash" ]] || die "Bottle pour changed the signed executable"
codesign --verify --strict --verbose=2 "$installed_binary"
# Standalone executables require codesign's notarization check.
codesign --verify --strict --verbose=4 --test-requirement '=notarized' --check-notarization "$installed_binary"
brew test shields/tap/mute-on-lock
printf '# Copyright © 2026 Michael Shields\n# SPDX-License-Identifier: Apache-2.0\n\n' >SHA256SUMS
shasum -a 256 "$bottle_filename" "mute-on-lock-$release_version-macos-arm64.zip" mute-on-lock.rb release.json >>SHA256SUMS
