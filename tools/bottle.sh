#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
cd "$(dirname "$0")/.."
source tools/release-lib.sh
require_release_context
read_metadata
brew tap shields/tap
tap_directory=$(brew --repository shields/tap)
mkdir -p "$tap_directory/Formula"
cp dist/mute-on-lock.rb "$tap_directory/Formula/mute-on-lock.rb"
brew style "$tap_directory/Formula/mute-on-lock.rb"
brew install --build-bottle shields/tap/mute-on-lock
installed_binary=$(brew --prefix shields/tap/mute-on-lock)/bin/mute-on-lock
[[ $("$installed_binary" --version) == "$release_version ($release_revision)" ]] || die "Source build identifies another release"
expected_hash=$(shasum -a 256 "$installed_binary" | awk '{print $1}')
cd dist
brew bottle --json --root-url "https://github.com/$release_repo/releases/download/$release_tag" shields/tap/mute-on-lock
bottle_json=mute-on-lock--$release_version.arm64_golden_gate.bottle.json
jq --exit-status '.["shields/tap/mute-on-lock"].bottle.cellar == "any_skip_relocation"' "$bottle_json"
bottle_filename=$(jq --exit-status --raw-output '.["shields/tap/mute-on-lock"].bottle.tags.arm64_golden_gate.filename' "$bottle_json")
[[ $bottle_filename == "mute-on-lock-$release_version.arm64_golden_gate.bottle.tar.gz" ]] || die "Unexpected bottle filename"
brew bottle --merge --write --no-commit "$bottle_json"
cp "$tap_directory/Formula/mute-on-lock.rb" mute-on-lock.rb
brew uninstall shields/tap/mute-on-lock
# Uninstalling revokes formula trust; a local pour needs an explicit grant: https://docs.brew.sh/Tap-Trust
brew trust --formula shields/tap/mute-on-lock
# Local bottle installation requires Homebrew’s developer mode.
HOMEBREW_DEVELOPER=1 brew install --force-bottle "./mute-on-lock--$release_version.arm64_golden_gate.bottle.tar.gz"
installed_binary=$(brew --prefix shields/tap/mute-on-lock)/bin/mute-on-lock
[[ $(shasum -a 256 "$installed_binary" | awk '{print $1}') == "$expected_hash" ]] || die "Bottle pour changed the executable"
[[ $("$installed_binary" --version) == "$release_version ($release_revision)" ]] || die "Bottle identifies another release"
brew test shields/tap/mute-on-lock
mv "mute-on-lock--$release_version.arm64_golden_gate.bottle.tar.gz" "$bottle_filename"
jq --arg hash "$expected_hash" '. + {executableSHA256: $hash}' release.json >bottle-release.json
mv bottle-release.json release.json
printf '# Copyright © 2026 Michael Shields\n# SPDX-License-Identifier: Apache-2.0\n\n' >SHA256SUMS
shasum -a 256 "$bottle_filename" mute-on-lock.rb release.json >>SHA256SUMS
