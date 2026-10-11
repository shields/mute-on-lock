#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
cd "$(dirname "$0")/.."
source tools/release-lib.sh
require_release_context
read_metadata
tag_refs=$(gh api "repos/$release_repo/git/matching-refs/tags/$release_tag")
tag_revision=$(jq --raw-output --arg ref "refs/tags/$release_tag" \
	'.[] | select(.ref == $ref) | .object.sha' <<<"$tag_refs")
if [[ -n $tag_revision ]]; then
	[[ $tag_revision == "$release_revision" ]] || die "Release tag already identifies another commit"
else
	jq --null-input --arg ref "refs/tags/$release_tag" --arg sha "$release_revision" \
		'{ref: $ref, sha: $sha}' >dist/tag-request.json
	gh api --method POST "repos/$release_repo/git/refs" --input dist/tag-request.json >/dev/null
fi
