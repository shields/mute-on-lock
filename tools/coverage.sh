#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
cd "$(dirname "$0")/.."
products_directory=$(swift build --show-bin-path --disable-automatic-resolution)
test_executable=$products_directory/LockAudioTests.xctest/Contents/MacOS/LockAudioTests
profile=$products_directory/codecov/default.profdata
xcrun llvm-cov report "$test_executable" --instr-profile "$profile" Sources/LockAudio
