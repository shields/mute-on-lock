// Copyright © 2026 Michael Shields
// SPDX-License-Identifier: Apache-2.0

import Testing

@testable import LockAudio

struct MuteControlPlanTests {
  @Test func masterControlAvoidsChannelProbes() throws {
    let controls = try MuteControlPlan.resolve(
      device: 1, writable: { $0 == 0 },
      channels: {
        Issue.record("Master control must avoid stream queries")
        return 2
      })
    #expect(controls == [0])
  }

  @Test func requiresEveryChannelBeforeReturningAPlan() throws {
    let controls = try MuteControlPlan.resolve(
      device: 1, writable: { $0 > 0 }, channels: { 3 })
    #expect(controls == [1, 2, 3])
    #expect(throws: AudioFailure.unsupported(device: 1)) {
      try MuteControlPlan.resolve(device: 1, writable: { $0 == 1 }, channels: { 2 })
    }
    #expect(throws: AudioFailure.unsupported(device: 1)) {
      try MuteControlPlan.resolve(device: 1, writable: { _ in false }, channels: { 0 })
    }
  }
}
