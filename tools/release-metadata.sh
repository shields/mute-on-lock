#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
cd "$(dirname "$0")/.."
source tools/release-lib.sh
release_revision=$(git rev-parse HEAD)
[[ $release_revision == "${GITHUB_SHA:-$release_revision}" ]] || die "Checkout differs from the event commit"
release_version=$(tools/version.sh "$release_revision")
validate_version "$release_version"
mkdir -p dist
jq --null-input --arg version "$release_version" --arg revision "$release_revision" \
	'{copyright: "Copyright © 2026 Michael Shields", license: "Apache-2.0", version: $version, revision: $revision}' \
	>dist/release.json
if [[ -n ${GITHUB_OUTPUT:-} ]]; then
	printf 'version=%s\nrevision=%s\n' "$release_version" "$release_revision" >>"$GITHUB_OUTPUT"
fi
