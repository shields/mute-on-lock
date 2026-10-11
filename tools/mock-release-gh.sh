#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
printf '%s\n' "$*" >>"$MOCK_LOG"
case "$1 $2" in
'api --paginate')
	[[ $# -eq 4 ]] || exit 64
	[[ $3 == --slurp ]] || exit 64
	[[ $4 == 'repos/shields/mute-on-lock/releases?per_page=100' ]] || exit 64
	case $MOCK_STATE in
	new) echo '[[]]' ;;
	draft) echo '[[{"draft":true,"prerelease":false,"tag_name":"v0.20261010.1"}]]' ;;
	existing) echo '[[{"draft":false,"prerelease":false,"tag_name":"v0.20261010.1"}]]' ;;
	older) echo '[[],[{"draft":false,"prerelease":false,"tag_name":"v0.20261011.1"}]]' ;;
	*) exit 64 ;;
	esac
	;;
'release create')
	asset_count=0
	for argument in "$@"; do
		case $argument in
		dist/*)
			[[ -f $argument ]] || exit 64
			case $argument in
			dist/mute-on-lock-0.20261010.1.arm64_golden_gate.bottle.tar.gz | dist/mute-on-lock.rb | dist/release.json | dist/SHA256SUMS) ;;
			*) exit 64 ;;
			esac
			asset_count=$((asset_count + 1))
			;;
		esac
	done
	[[ $asset_count -eq 4 ]] || exit 64
	;;
'release edit' | 'release delete') ;;
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
	[[ -n $destination ]] || exit 64
	mkdir -p "$destination"
	cp "$MOCK_PUBLISHED"/mute-on-lock.rb "$MOCK_PUBLISHED"/release.json "$MOCK_PUBLISHED"/SHA256SUMS "$destination/"
	;;
*)
	echo 'Unexpected mock GitHub operation' >&2
	exit 64
	;;
esac
