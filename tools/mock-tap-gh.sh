#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
printf '%s\n' "$*" >>"$MOCK_LOG"
case "$1 $2" in
'api repos/shields/homebrew-tap/git/ref/heads/main') printf '%040d\n' 1 ;;
'api repos/shields/homebrew-tap/git/commits/0000000000000000000000000000000000000001') printf '%040d\n' 2 ;;
'api repos/shields/homebrew-tap/git/trees/0000000000000000000000000000000000000002?recursive=1')
	if [[ $# -eq 2 ]]; then
		printf '{"tree":[]}\n'
	elif [[ $MOCK_STATE == invalid_version ]]; then
		printf '%040d\n' 3
	fi
	;;
'api repos/shields/homebrew-tap/git/blobs/0000000000000000000000000000000000000003')
	printf '  version "development"\n' | base64
	;;
'api repos/shields/homebrew-tap/git/matching-refs/heads/release/mute-on-lock-0.20261010.1') echo '[]' ;;
'api --method')
	[[ $# -eq 6 && $5 == --input ]]
	case "$3 $4" in
	'POST repos/shields/homebrew-tap/git/refs' | 'PUT repos/shields/homebrew-tap/contents/Formula/mute-on-lock.rb')
		jq --exit-status 'type == "object"' "$6" >/dev/null
		;;
	*) exit 64 ;;
	esac
	;;
'pr list') echo 7 ;;
'pr view')
	case $MOCK_STATE in
	pending) echo true ;;
	enabled) echo false ;;
	failure)
		echo 'Unable to read pull request' >&2
		exit 7
		;;
	*) exit 64 ;;
	esac
	;;
'pr merge') ;;
*)
	echo 'Unexpected mock GitHub operation' >&2
	exit 64
	;;
esac
