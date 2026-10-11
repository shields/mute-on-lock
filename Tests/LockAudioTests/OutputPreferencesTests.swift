// Copyright © 2026 Michael Shields
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Testing

@testable import LockAudio

@MainActor
struct OutputPreferencesTests {
  @Test func overridesPersistAndAutoRemovesThem() throws {
    let domain = "dev.msrl.mute-on-lock.tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: domain))
    defer { defaults.removePersistentDomain(forName: domain) }
    let preferences = OutputPreferences(defaults: defaults)
    #expect(try preferences.overrides().isEmpty)
    try preferences.set(uid: "headset", kind: .headphones)
    try preferences.set(uid: "speaker", kind: .speakers)
    let reopenedDefaults = try #require(UserDefaults(suiteName: domain))
    let reopened = OutputPreferences(defaults: reopenedDefaults)
    #expect(try reopened.overrides() == ["headset": .headphones, "speaker": .speakers])
    try preferences.set(uid: "headset", kind: nil)
    #expect(try preferences.overrides() == ["speaker": .speakers])
  }

  @Test func malformedPreferencesAreFatal() throws {
    let domain = "dev.msrl.mute-on-lock.tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: domain))
    defer { defaults.removePersistentDomain(forName: domain) }
    let preferences = OutputPreferences(defaults: defaults)
    defaults.set(["headset": "unknown"], forKey: "deviceOverrides")
    #expect(throws: PreferenceFailure.self) { try preferences.overrides() }
    defaults.set(3, forKey: "deviceOverrides")
    #expect(throws: PreferenceFailure.self) { try preferences.overrides() }
  }
}
