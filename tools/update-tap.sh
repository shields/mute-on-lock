#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
cd "$(dirname "$0")/.."
source tools/release-lib.sh
require_release_context
read_metadata
tap_repo=shields/homebrew-tap
formula_path=Formula/mute-on-lock.rb
branch_name=release/mute-on-lock-$release_version
main_commit=$(gh api "repos/$tap_repo/git/ref/heads/main" --jq .object.sha)
main_tree=$(gh api "repos/$tap_repo/git/commits/$main_commit" --jq .tree.sha)
formula_blob=$(gh api "repos/$tap_repo/git/trees/$main_tree?recursive=1" --jq '.tree[] | select(.path == "Formula/mute-on-lock.rb") | .sha')
if [[ -n $formula_blob ]]; then
	current_formula=$(gh api "repos/$tap_repo/git/blobs/$formula_blob" --jq .content | base64 --decode)
	current_version=$(sed -n 's/^  version "\([^"]*\)".*/\1/p' <<<"$current_formula")
	# Conditional expressions discard command-substitution exit status.
	version_order=$(compare_versions "$release_version" "$current_version")
	if [[ $version_order != newer ]]; then exit 0; fi
fi
branch_refs=$(gh api "repos/$tap_repo/git/matching-refs/heads/$branch_name")
branch_commit=$(jq --raw-output --arg ref "refs/heads/$branch_name" '.[] | select(.ref == $ref) | .object.sha' <<<"$branch_refs")
if [[ -z $branch_commit ]]; then
	jq --null-input --arg ref "refs/heads/$branch_name" --arg sha "$main_commit" '{ref: $ref, sha: $sha}' >dist/branch-request.json
	gh api --method POST "repos/$tap_repo/git/refs" --input dist/branch-request.json >/dev/null
	branch_commit=$main_commit
fi
branch_tree_sha=$(gh api "repos/$tap_repo/git/commits/$branch_commit" --jq .tree.sha)
branch_tree=$(gh api "repos/$tap_repo/git/trees/$branch_tree_sha?recursive=1")
branch_blob=$(jq --raw-output '.tree[] | select(.path == "Formula/mute-on-lock.rb") | .sha' <<<"$branch_tree")
jq --null-input --arg message "Update mute-on-lock to $release_version" --arg branch "$branch_name" \
	--arg sha "$branch_blob" --rawfile formula dist/published/mute-on-lock.rb \
	'{message: $message, branch: $branch, content: ($formula | @base64)} + (if $sha == "" then {} else {sha: $sha} end)' \
	>dist/formula-request.json
if [[ -n $branch_blob ]]; then
	gh api "repos/$tap_repo/git/blobs/$branch_blob" --jq .content | base64 --decode >dist/current-formula.rb
fi
if [[ -z $branch_blob ]] || ! cmp -s dist/current-formula.rb dist/published/mute-on-lock.rb; then
	gh api --method PUT "repos/$tap_repo/contents/$formula_path" --input dist/formula-request.json >/dev/null
fi
pr_number=$(gh pr list --repo "$tap_repo" --head "$branch_name" --state open --json number --jq '.[0].number // empty')
if [[ -z $pr_number ]]; then
	printf 'Install mute-on-lock %s from its tested release. The bottle preserves the verified executable.\n' "$release_version" >dist/tap-pr-body.txt
	gh pr create --repo "$tap_repo" --head "$branch_name" --base main \
		--title "Update mute-on-lock to $release_version" --body-file dist/tap-pr-body.txt
	pr_number=$(gh pr list --repo "$tap_repo" --head "$branch_name" --state open --json number --jq '.[0].number')
fi
auto_merge_needed=$(gh pr view "$pr_number" --repo "$tap_repo" --json autoMergeRequest --jq '.autoMergeRequest == null')
if [[ $auto_merge_needed == true ]]; then
	gh pr merge "$pr_number" --repo "$tap_repo" --auto --squash
fi
