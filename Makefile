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

SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c
SWIFT_BUILD_FLAGS ?= --disable-automatic-resolution

.PHONY: setup ci-setup build test coverage lint fmt run version prepare-release release-tag release-sign release-bottle release-publish release-tap

setup:
	bun install --frozen-lockfile
	lefthook install

ci-setup:
	brew install lefthook shellcheck shfmt zizmor ripgrep jq
	$(MAKE) setup

build:
	./tools/build-info.sh
	swift build --configuration release $(SWIFT_BUILD_FLAGS)

test:
	./tools/test-release.sh
	./tools/build-info.sh
	swift test --enable-code-coverage --disable-automatic-resolution

coverage: test
	./tools/coverage.sh

lint:
	./tools/check-notices.sh
	swift format lint --strict --recursive Package.swift Sources Tests tools/*.swift
	bunx --no-install prettier --check .
	shellcheck --external-sources tools/*.sh
	shfmt -d tools/*.sh
	if [[ -d .github/workflows ]]; then zizmor --persona pedantic .github/workflows; fi

fmt:
	swift format format --in-place --recursive Package.swift Sources Tests tools/*.swift
	bunx --no-install prettier --write .
	shfmt -w tools/*.sh

run: build
	.build/release/mute-on-lock run

version:
	./tools/version.sh

prepare-release:
	./tools/release-metadata.sh
	VERSION="$$(jq -r .version dist/release.json)" REVISION="$$(jq -r .revision dist/release.json)" $(MAKE) build
	cp -p .build/release/mute-on-lock dist/mute-on-lock

release-tag:
	./tools/create-tag.sh

release-sign:
	./tools/sign.sh

release-bottle:
	./tools/formula.sh
	./tools/bottle.sh

release-publish:
	./tools/publish.sh

release-tap:
	cp dist/published/release.json dist/release.json
	./tools/update-tap.sh
