// Copyright © 2026 Michael Shields
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Testing

@testable import LockAudio

@MainActor
private final class FakeAudio: AudioAccess {
  var outputs: [UInt32] = [1]
  var kinds: [UInt32: OutputKind] = [:]
  var controls: [UInt32: [UInt32]] = [:]
  var muted: Set<String> = []
  var reads: [UInt32] = []
  var writes: [String] = []
  var failedControl: UInt32?
  var failure: AudioFailure?
  var transientFailures = 0
  var snapshots = 0
  var onRetry: (() -> Void)?

  func defaultOutputs() throws -> [UInt32] {
    snapshots += 1
    if snapshots > 1 { onRetry?() }
    return outputs
  }

  func outputKind(of device: UInt32) throws -> OutputKind {
    if transientFailures > 0 {
      transientFailures -= 1
      throw AudioFailure.status(operation: "Device vanished", code: -1)
    }
    return kinds[device] ?? .unknown
  }

  func muteControls(of device: UInt32) throws -> [UInt32] {
    reads.append(device)
    if let failure { throw failure }
    return controls[device] ?? [0]
  }

  func isMuted(device: UInt32, control: UInt32) throws -> Bool {
    muted.contains("\(device):\(control)")
  }

  func mute(device: UInt32, control: UInt32) throws {
    if control == failedControl { throw AudioFailure.status(operation: "Write failed", code: -2) }
    let key = "\(device):\(control)"
    writes.append(key)
    muted.insert(key)
  }

  func isDisappearingDevice(_ error: any Error) -> Bool {
    guard case AudioFailure.status(_, -1) = error else { return false }
    return true
  }
}

@MainActor
struct PolicyTests {
  @Test func locksMuteBothDefaultsAndUnlockDoesNotRestore() throws {
    let audio = FakeAudio()
    audio.outputs = [1, 2]
    let policy = LockPolicy(audio: audio)
    try policy.outputsChanged()
    #expect(audio.snapshots == 0)
    try policy.sessionChanged(locked: true)
    #expect(audio.writes == ["1:0", "2:0"])
    try policy.sessionChanged(locked: false)
    audio.outputs = [3]
    try policy.outputsChanged()
    #expect(audio.writes == ["1:0", "2:0"])
    #expect(audio.muted == ["1:0", "2:0"])
  }

  @Test func headphonesReceiveNoMuteReadsOrWrites() throws {
    let audio = FakeAudio()
    audio.outputs = [1, 2, 3]
    audio.kinds = [1: .headphones, 2: .headphones, 3: .speakers]
    try LockPolicy(audio: audio).sessionChanged(locked: true)
    #expect(audio.reads == [3])
    #expect(audio.writes == ["3:0"])
  }

  @Test func deduplicatesAndDoesNotWriteAlreadyMutedControls() throws {
    let audio = FakeAudio()
    audio.outputs = [1, 1, 0]
    audio.muted = ["1:0"]
    let policy = LockPolicy(audio: audio)
    try policy.sessionChanged(locked: true)
    try policy.sessionChanged(locked: true)
    try policy.outputsChanged()
    #expect(audio.reads == [1, 1, 1])
    #expect(audio.writes.isEmpty)
  }

  @Test func disconnectWhileLockedMutesSpeakers() throws {
    let audio = FakeAudio()
    audio.kinds = [1: .headphones]
    let policy = LockPolicy(audio: audio)
    try policy.sessionChanged(locked: true)
    audio.outputs = [2]
    try policy.outputsChanged()
    #expect(audio.writes == ["2:0"])
  }

  @Test func mutesEveryChannel() throws {
    let audio = FakeAudio()
    audio.controls = [1: [1, 2, 3]]
    audio.muted = ["1:2"]
    try LockPolicy(audio: audio).sessionChanged(locked: true)
    #expect(audio.writes == ["1:1", "1:3"])
  }

  @Test func partialWriteFailureIsFatal() {
    let audio = FakeAudio()
    audio.controls = [1: [1, 2]]
    audio.failedControl = 2
    #expect(throws: AudioFailure.self) {
      try LockPolicy(audio: audio).sessionChanged(locked: true)
    }
    #expect(audio.writes == ["1:1"])
    #expect(audio.snapshots == 1)
  }

  @Test func missingOutputsAreNormal() throws {
    let audio = FakeAudio()
    audio.outputs = [0]
    try LockPolicy(audio: audio).sessionChanged(locked: true)
    #expect(audio.writes.isEmpty)
  }

  @Test func vanishedDeviceRefreshesDefaultsOnce() throws {
    let audio = FakeAudio()
    audio.transientFailures = 1
    audio.onRetry = { audio.outputs = [2] }
    try LockPolicy(audio: audio).sessionChanged(locked: true)
    #expect(audio.snapshots == 2)
    #expect(audio.writes == ["2:0"])
  }

  @Test func persistentDeviceErrorAndUnsupportedControlsThrow() {
    let audio = FakeAudio()
    audio.transientFailures = 2
    #expect(throws: AudioFailure.self) {
      try LockPolicy(audio: audio).sessionChanged(locked: true)
    }
    #expect(audio.snapshots == 2)
    audio.transientFailures = 0
    audio.controls = [1: []]
    #expect(throws: AudioFailure.unsupported(device: 1)) {
      try LockPolicy(audio: audio).sessionChanged(locked: true)
    }
    audio.failure = .status(operation: "Denied", code: -2)
    #expect(throws: AudioFailure.self) {
      try LockPolicy(audio: audio).sessionChanged(locked: true)
    }
    #expect(audio.writes.isEmpty)
  }
}
