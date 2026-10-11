#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
cd "$(dirname "$0")/.."
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/mute-on-lock-release-test.XXXXXX")
trap 'rm -rf "$test_directory"' EXIT
mkdir -p "$test_directory/tools" "$test_directory/bin" "$test_directory/canonical" "$test_directory/dist"
cp tools/release-lib.sh tools/publish.sh "$test_directory/tools/"
cp tools/mock-release-gh.sh "$test_directory/bin/gh"
chmod +x "$test_directory/bin/gh"
export MOCK_LOG=$test_directory/calls MOCK_PUBLISHED=$test_directory/canonical
export GITHUB_ACTIONS=true GITHUB_REPOSITORY=shields/mute-on-lock GITHUB_REF=refs/heads/main
export GITHUB_SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
export GITHUB_OUTPUT=$test_directory/outputs
export PATH=$test_directory/bin:$PATH
printf '# Copyright © 2026 Michael Shields\n# SPDX-License-Identifier: Apache-2.0\n' >"$MOCK_PUBLISHED/mute-on-lock.rb"
jq --null-input --arg revision "$GITHUB_SHA" \
	'{copyright:"Copyright © 2026 Michael Shields", license:"Apache-2.0", version:"0.20261010.1", revision:$revision, executableSHA256:("b" * 64)}' \
	>"$MOCK_PUBLISHED/release.json"
printf '# Copyright © 2026 Michael Shields\n# SPDX-License-Identifier: Apache-2.0\n' >"$MOCK_PUBLISHED/mute-on-lock-0.20261010.1.arm64_golden_gate.bottle.tar.gz"
(
	cd "$MOCK_PUBLISHED"
	shasum -a 256 mute-on-lock-0.20261010.1.arm64_golden_gate.bottle.tar.gz mute-on-lock.rb release.json >SHA256SUMS
)
cp "$MOCK_PUBLISHED"/mute-on-lock.rb "$MOCK_PUBLISHED"/release.json "$MOCK_PUBLISHED"/SHA256SUMS \
	"$MOCK_PUBLISHED/mute-on-lock-0.20261010.1.arm64_golden_gate.bottle.tar.gz" "$test_directory/dist/"
export MOCK_STATE=new
bash "$test_directory/tools/publish.sh"
rg --quiet '^release create ' "$MOCK_LOG"
rg --quiet '^release edit .*--latest=true$' "$MOCK_LOG"
rm -rf "$test_directory/dist/published"
: >"$MOCK_LOG"
export MOCK_STATE=draft
bash "$test_directory/tools/publish.sh"
rg --quiet '^release delete v0\.20261010\.1 .*--yes$' "$MOCK_LOG"
rg --quiet '^release create ' "$MOCK_LOG"
rg --quiet '^release edit .*--latest=true$' "$MOCK_LOG"
rm -rf "$test_directory/dist/published"
: >"$MOCK_LOG"
export MOCK_STATE=existing
bash "$test_directory/tools/publish.sh"
if rg --quiet '^release (create|edit|delete)' "$MOCK_LOG"; then
	echo 'Rerun attempted to modify a published release' >&2
	exit 1
fi
cmp "$test_directory/dist/published/mute-on-lock.rb" "$MOCK_PUBLISHED/mute-on-lock.rb"
rm -rf "$test_directory/dist/published"
: >"$MOCK_LOG"
export MOCK_STATE=older
bash "$test_directory/tools/publish.sh"
rg --quiet '^release edit .*--latest=false$' "$MOCK_LOG"
rm -rf "$test_directory/dist/published"
export MOCK_STATE=existing
jq '.executableSHA256 = "invalid"' "$MOCK_PUBLISHED/release.json" >"$test_directory/invalid.json"
mv "$test_directory/invalid.json" "$MOCK_PUBLISHED/release.json"
(
	cd "$MOCK_PUBLISHED"
	shasum -a 256 mute-on-lock.rb release.json >SHA256SUMS
)
if bash "$test_directory/tools/publish.sh" >/dev/null 2>&1; then
	echo 'Accepted an invalid published executable checksum' >&2
	exit 1
fi
jq '.executableSHA256 = ("b" * 64)' "$MOCK_PUBLISHED/release.json" >"$test_directory/valid.json"
mv "$test_directory/valid.json" "$MOCK_PUBLISHED/release.json"
(
	cd "$MOCK_PUBLISHED"
	shasum -a 256 mute-on-lock.rb release.json >SHA256SUMS
)
printf 'corruption\n' >>"$MOCK_PUBLISHED/mute-on-lock.rb"
if bash "$test_directory/tools/publish.sh" >/dev/null 2>&1; then
	echo 'Accepted corrupted published metadata' >&2
	exit 1
fi
