#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
cd "$(dirname "$0")/.."
while IFS= read -r -d '' notice_file; do
	if ! rg -q 'Copyright © 2026 Michael Shields' "$notice_file"; then
		echo "Missing copyright: $notice_file" >&2
		exit 1
	fi
	if ! rg -q 'Apache License|Apache-2.0' "$notice_file"; then
		echo "Missing license: $notice_file" >&2
		exit 1
	fi
done < <(git ls-files --cached --others --exclude-standard -z)
