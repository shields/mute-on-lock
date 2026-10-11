#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
cd "$(dirname "$0")/.."
source tools/release-lib.sh
require_release_context
read_metadata
# gh api supports --slurp for pagination: https://cli.github.com/manual/gh_api
all_releases=$(gh api --paginate --slurp "repos/$release_repo/releases?per_page=100")
existing_release=$(jq --compact-output --arg tag "$release_tag" 'flatten | .[] | select(.tag_name == $tag)' <<<"$all_releases")
if [[ -n $existing_release ]] && [[ $(jq --raw-output '.draft' <<<"$existing_release") == true ]]; then
	gh release delete "$release_tag" --repo "$release_repo" --yes
	existing_release=
fi
promote=true
while IFS= read -r published_tag; do
	[[ $published_tag =~ ^v0\.[0-9]{8}\.[1-9][0-9]{0,8}$ ]] || continue
	if [[ $(compare_versions "$release_version" "${published_tag#v}") == older ]]; then promote=false; fi
done < <(jq --raw-output 'flatten | .[] | select(.draft == false and .prerelease == false) | .tag_name' <<<"$all_releases")
if [[ -z $existing_release ]]; then
	gh release create "$release_tag" --repo "$release_repo" --verify-tag --draft \
		--title "Mute on lock $release_version" --generate-notes \
		"dist/mute-on-lock-$release_version-macos-arm64.zip" \
		"dist/mute-on-lock-$release_version.arm64_golden_gate.bottle.tar.gz" \
		dist/mute-on-lock.rb dist/release.json dist/SHA256SUMS
	gh release edit "$release_tag" --repo "$release_repo" --draft=false --latest="$promote"
fi
mkdir -p dist/published
gh release download "$release_tag" --repo "$release_repo" --dir dist/published \
	--pattern mute-on-lock.rb --pattern release.json --pattern SHA256SUMS
jq --exit-status '.notarization == "Accepted" and (.executableSHA256 | test("^[0-9a-f]{64}$"))' dist/published/release.json >/dev/null
(
	cd dist/published
	awk '$2 == "mute-on-lock.rb" || $2 == "release.json"' SHA256SUMS >metadata.sha256
	[[ $(wc -l <metadata.sha256 | tr -d ' ') == 2 ]] || die "Published metadata checksums are missing"
	shasum -a 256 --check metadata.sha256
)
[[ $(jq --raw-output '.revision' dist/published/release.json) == "$release_revision" ]] || die "Published release identifies another source commit"
[[ $(jq --raw-output '.version' dist/published/release.json) == "$release_version" ]] || die "Published release identifies another version"
if [[ -n ${GITHUB_OUTPUT:-} ]]; then printf 'promote=%s\n' "$promote" >>"$GITHUB_OUTPUT"; fi
