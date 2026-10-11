#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

die() {
	echo "$*" >&2
	exit 1
}

validate_version() {
	[[ $1 =~ ^0\.[0-9]{8}\.[1-9][0-9]{0,8}$ ]] || die "Invalid release version: $1"
}

compare_versions() {
	local left_date left_count right_date right_count
	validate_version "$1"
	validate_version "$2"
	left_date=${1#0.}
	left_count=${left_date#*.}
	left_date=${left_date%%.*}
	right_date=${2#0.}
	right_count=${right_date#*.}
	right_date=${right_date%%.*}
	if ((10#$left_date > 10#$right_date)) ||
		{ ((10#$left_date == 10#$right_date)) && ((10#$left_count > 10#$right_count)); }; then
		echo newer
	elif [[ $1 == "$2" ]]; then
		echo equal
	else
		echo older
	fi
}

require_release_context() {
	[[ ${GITHUB_ACTIONS:-} == true && ${GITHUB_REPOSITORY:-} == shields/mute-on-lock &&
		${GITHUB_REF:-} == refs/heads/main ]] || die "Publishing runs only in this repository's main-branch Actions workflow"
}

read_metadata() {
	release_version=$(jq --exit-status --raw-output '.version' dist/release.json)
	release_revision=$(jq --exit-status --raw-output '.revision' dist/release.json)
	validate_version "$release_version"
	[[ $release_revision =~ ^[0-9a-f]{40}$ ]] || die "Invalid source revision"
	[[ $release_revision == "${GITHUB_SHA:-$release_revision}" ]] || die "Metadata does not identify the tested commit"
	release_tag=v$release_version
	release_repo=shields/mute-on-lock
	export release_version release_revision release_tag release_repo
}
