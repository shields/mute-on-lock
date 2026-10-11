#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
cd "$(dirname "$0")/.."
source tools/release-lib.sh
[[ $(compare_versions 0.20261011.1 0.20261010.99) == newer ]] || die "Incorrect release version ordering"
[[ $(compare_versions 0.20261010.10 0.20261010.9) == newer ]] || die "Incorrect release version ordering"
[[ $(compare_versions 0.20261010.1 0.20261010.1) == equal ]] || die "Incorrect release version ordering"
[[ $(compare_versions 0.20261010.9 0.20261010.10) == older ]] || die "Incorrect release version ordering"
[[ $(compare_versions 0.20261009.99 0.20261010.1) == older ]] || die "Incorrect release version ordering"
if (validate_version '0.20261010.1; echo unsafe') 2>/dev/null; then die "Accepted an invalid version"; fi
for invalid in 0.20261010.01 0.20261010.0 0.20261010.1234567890; do
	if (validate_version "$invalid") 2>/dev/null; then die "Accepted a noncanonical version"; fi
done
if (GITHUB_ACTIONS=false require_release_context) 2>/dev/null; then die "Allowed local publishing"; fi
if (GITHUB_ACTIONS=true GITHUB_REPOSITORY=shields/mute-on-lock GITHUB_REF=refs/pull/1/merge require_release_context) 2>/dev/null; then
	die "Allowed pull-request publishing"
fi
GITHUB_ACTIONS=true GITHUB_REPOSITORY=shields/mute-on-lock GITHUB_REF=refs/heads/main require_release_context
bash tools/test-publish.sh
bash tools/test-update-tap.sh
