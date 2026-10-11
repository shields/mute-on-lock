#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
cd "$(dirname "$0")/.."
gitcalver_version=v20261007.1
gitcalver_sha256=7f16ff978449aba9c6b5303ba160b365fb2cc891dd6a756ac196c54e61abec8c
mkdir -p .tools
if [[ ! -f .tools/gitcalver.sh ]]; then
	curl --fail --location --silent --show-error \
		"https://github.com/gitcalver/sh/releases/download/$gitcalver_version/gitcalver.sh" \
		-o .tools/gitcalver.sh
fi
printf '%s  %s\n' "$gitcalver_sha256" .tools/gitcalver.sh | shasum -a 256 --check >&2
sh .tools/gitcalver.sh --branch main --prefix 0. --no-dirty "${1:-HEAD}"
