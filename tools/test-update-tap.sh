#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
cd "$(dirname "$0")/.."
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/mute-on-lock-tap-test.XXXXXX")
trap 'rm -rf "$test_directory"' EXIT
mkdir -p "$test_directory/tools" "$test_directory/bin" "$test_directory/dist/published"
cp tools/release-lib.sh tools/update-tap.sh "$test_directory/tools/"
cp tools/mock-tap-gh.sh "$test_directory/bin/gh"
chmod +x "$test_directory/bin/gh"
export MOCK_LOG=$test_directory/calls
export GITHUB_ACTIONS=true GITHUB_REPOSITORY=shields/mute-on-lock GITHUB_REF=refs/heads/main
export GITHUB_SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
export PATH=$test_directory/bin:$PATH
jq --null-input --arg revision "$GITHUB_SHA" \
	'{copyright:"Copyright © 2026 Michael Shields", license:"Apache-2.0", version:"0.20261010.1", revision:$revision}' \
	>"$test_directory/dist/release.json"
printf '# Copyright © 2026 Michael Shields\n# SPDX-License-Identifier: Apache-2.0\n' \
	>"$test_directory/dist/published/mute-on-lock.rb"
for state in pending enabled failure invalid_version older equal newer; do
	export MOCK_STATE=$state
	: >"$MOCK_LOG"
	status=0
	/bin/bash "$test_directory/tools/update-tap.sh" >"$test_directory/output" 2>"$test_directory/error" || status=$?
	case $state in
	failure)
		[[ $status -eq 7 ]] || {
			echo 'Tap updater swallowed the PR status error' >&2
			exit 1
		}
		rg --quiet '^Unable to read pull request$' "$test_directory/error"
		;;
	invalid_version)
		[[ $status -eq 1 ]] || {
			echo 'Tap updater accepted a malformed current version' >&2
			exit 1
		}
		rg --quiet '^Invalid release version: development$' "$test_directory/error"
		if rg --quiet '^api --method ' "$MOCK_LOG"; then
			echo 'Tap updater modified a branch with an invalid current version' >&2
			exit 1
		fi
		;;
	*)
		[[ $status -eq 0 ]] || exit "$status"
		;;
	esac
	if [[ $state == equal || $state == newer ]]; then
		if rg --quiet '^(api --method |pr )' "$MOCK_LOG"; then
			echo 'Tap updater modified a formula that is already current' >&2
			exit 1
		fi
	elif [[ $state == older ]]; then
		rg --quiet '^api --method PUT repos/shields/homebrew-tap/contents/Formula/mute-on-lock.rb ' "$MOCK_LOG"
	fi
	if [[ $state == pending ]]; then
		rg --quiet '^pr merge 7 --repo shields/homebrew-tap --auto --squash$' "$MOCK_LOG"
	elif rg --quiet '^pr merge ' "$MOCK_LOG"; then
		echo 'Tap updater attempted an unexpected merge' >&2
		exit 1
	fi
done
