// Copyright © 2026 Michael Shields
// SPDX-License-Identifier: Apache-2.0

import CoreAudio
import IOKit.audio
import Testing

@testable import LockAudio

struct OutputClassifierTests {
  @Test func distinguishesTerminalTypes() {
    #expect(
      OutputClassifier.resolve(terminals: [kAudioStreamTerminalTypeHeadphones]) == .headphones)
    #expect(OutputClassifier.resolve(terminals: [kAudioStreamTerminalTypeSpeaker]) == .speakers)
    #expect(OutputClassifier.resolve(terminals: [kAudioStreamTerminalTypeLFESpeaker]) == .speakers)
    #expect(
      OutputClassifier.resolve(terminals: [
        kAudioStreamTerminalTypeHeadphones, kAudioStreamTerminalTypeSpeaker,
      ]) == .speakers)
    #expect(
      OutputClassifier.resolve(terminals: [kAudioStreamTerminalTypeHeadphones, 0]) == .unknown)
    #expect(OutputClassifier.resolve(terminals: []) == .unknown)
    #expect(OutputClassifier.resolve(terminals: [kAudioStreamTerminalTypeHDMI]) == .unknown)
  }

  @Test func recognizesUSBTerminalCodes() {
    #expect(OutputClassifier.resolve(terminals: [0x0302]) == .headphones)
    for code: UInt32 in [0x0301, 0x0304, 0x0305, 0x0306, 0x0307] {
      #expect(OutputClassifier.resolve(terminals: [code]) == .speakers)
    }
    #expect(OutputClassifier.resolve(terminals: [0x0300]) == .unknown)
  }

  @Test func selectedBuiltinSourceDeterminesTheCurrentRoute() {
    #expect(
      OutputClassifier.resolve(
        terminals: [kAudioStreamTerminalTypeSpeaker],
        builtinSources: [UInt32(kIOAudioOutputPortSubTypeHeadphones)]) == .headphones)
    #expect(
      OutputClassifier.resolve(
        terminals: [kAudioStreamTerminalTypeHeadphones],
        builtinSources: [UInt32(kIOAudioOutputPortSubTypeInternalSpeaker)]) == .speakers)
    #expect(OutputClassifier.resolve(terminals: [], builtinSources: [123]) == .unknown)
  }
}
