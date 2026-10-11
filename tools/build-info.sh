#!/bin/bash

# Copyright © 2026 Michael Shields
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

cd "$(dirname "$0")/.."
build_version=${VERSION:-development}
build_revision=${REVISION:-unknown}
if [[ ! $build_version =~ ^(development|0\.[0-9]{8}\.[0-9]+)$ ]]; then
	echo "Invalid build version" >&2
	exit 1
fi
if [[ ! $build_revision =~ ^(unknown|[0-9a-f]{40})$ ]]; then
	echo "Invalid build revision" >&2
	exit 1
fi
if [[ $build_version != development && $build_revision == unknown ]]; then
	echo "Release builds require a source revision" >&2
	exit 1
fi
mkdir -p Sources/BuildInfo
printf '// Copyright © 2026 Michael Shields\n// SPDX-License-Identifier: Apache-2.0\n\npublic enum BuildInfo {\n  public static let version = "%s"\n  public static let revision = "%s"\n}\n' \
	"$build_version" "$build_revision" >Sources/BuildInfo/BuildInfo.swift
