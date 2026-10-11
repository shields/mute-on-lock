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

.PHONY: setup build test lint fmt run

setup:
	bun install --frozen-lockfile
	lefthook install

build:
	./tools/build-info.sh
	swift build --configuration release --disable-automatic-resolution

test:
	./tools/build-info.sh
	swift test --enable-code-coverage --disable-automatic-resolution

lint:
	./tools/check-notices.sh
	swift format lint --strict --recursive Package.swift Sources Tests tools/*.swift
	bunx --no-install prettier --check .
	shellcheck tools/*.sh
	shfmt -d tools/*.sh
	if [[ -d .github/workflows ]]; then zizmor --persona pedantic .github/workflows; fi

fmt:
	swift format format --in-place --recursive Package.swift Sources Tests tools/*.swift
	bunx --no-install prettier --write .
	shfmt -w tools/*.sh

run: build
	.build/release/mute-on-lock run
