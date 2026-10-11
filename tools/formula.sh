#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
cd "$(dirname "$0")/.."
source tools/release-lib.sh
read_metadata
source_url=https://github.com/shields/mute-on-lock/archive/refs/tags/$release_tag.tar.gz
parser_version=$(jq --exit-status --raw-output '.pins[] | select(.identity == "swift-argument-parser") | .state.version' Package.resolved)
[[ $parser_version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Invalid argument parser version"
parser_revision=$(jq --exit-status --raw-output '.pins[] | select(.identity == "swift-argument-parser") | .state.revision' Package.resolved)
[[ $parser_revision =~ ^[0-9a-f]{40}$ ]] || die "Invalid argument parser revision"
curl --fail --location --silent --show-error "$source_url" -o dist/source.tar.gz
curl --fail --location --silent --show-error \
	"https://github.com/apple/swift-argument-parser/archive/$parser_revision.tar.gz" \
	-o dist/argument-parser.tar.gz
source_hash=$(shasum -a 256 dist/source.tar.gz | awk '{print $1}')
parser_hash=$(shasum -a 256 dist/argument-parser.tar.gz | awk '{print $1}')
sed -e "s/@@VERSION@@/$release_version/g" -e "s/@@REVISION@@/$release_revision/g" \
	-e "s/@@SOURCE_SHA256@@/$source_hash/g" -e "s/@@PARSER_VERSION@@/$parser_version/g" \
	-e "s/@@PARSER_REVISION@@/$parser_revision/g" -e "s/@@PARSER_SHA256@@/$parser_hash/g" tools/mute-on-lock.rb.in >dist/mute-on-lock.rb
jq --arg source "$source_hash" --arg parser "$parser_hash" \
	'. + {sourceSHA256: $source, argumentParserSHA256: $parser}' dist/release.json >dist/formula-release.json
mv dist/formula-release.json dist/release.json
