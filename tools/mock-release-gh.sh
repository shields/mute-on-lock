#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
printf '%s\n' "$*" >>"$MOCK_LOG"
case "$1 $2" in
'api --paginate')
	[[ $# -eq 4 ]]
	[[ $3 == --slurp ]]
	[[ $4 == 'repos/shields/mute-on-lock/releases?per_page=100' ]]
	case $MOCK_STATE in
	new) echo '[[]]' ;;
	draft) echo '[[{"draft":true,"prerelease":false,"tag_name":"v0.20261010.1"}]]' ;;
	existing) echo '[[{"draft":false,"prerelease":false,"tag_name":"v0.20261010.1"}]]' ;;
	older) echo '[[],[{"draft":false,"prerelease":false,"tag_name":"v0.20261011.1"}]]' ;;
	*) exit 64 ;;
	esac
	;;
'release create' | 'release edit' | 'release delete') ;;
'release download')
	destination=
	while [[ $# -gt 0 ]]; do
		case $1 in
		--dir)
			destination=$2
			shift 2
			;;
		*) shift ;;
		esac
	done
	[[ -n $destination ]]
	mkdir -p "$destination"
	cp "$MOCK_PUBLISHED"/mute-on-lock.rb "$MOCK_PUBLISHED"/release.json "$MOCK_PUBLISHED"/SHA256SUMS "$destination/"
	;;
*)
	echo 'Unexpected mock GitHub operation' >&2
	exit 64
	;;
esac
