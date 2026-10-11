// Copyright © 2026 Michael Shields
// SPDX-License-Identifier: Apache-2.0

import CoreAudio
import IOKit.audio

public enum OutputKind: String, Sendable {
  case headphones
  case speakers
  case unknown
}

enum OutputClassifier {
  static func resolve(terminals: [UInt32], builtinSources: [UInt32] = []) -> OutputKind {
    if !builtinSources.isEmpty {
      return combine(
        builtinSources.map { value in
          switch value {
          case UInt32(kIOAudioOutputPortSubTypeHeadphones): .headphones
          case UInt32(kIOAudioOutputPortSubTypeInternalSpeaker),
            UInt32(kIOAudioOutputPortSubTypeExternalSpeaker):
            .speakers
          default: .unknown
          }
        })
    }
    return combine(
      terminals.map { value in
        switch value {
        case kAudioStreamTerminalTypeHeadphones, 0x0302: .headphones
        case kAudioStreamTerminalTypeSpeaker, 0x0301, 0x0304...0x0307,
          kAudioStreamTerminalTypeLFESpeaker,
          kAudioStreamTerminalTypeReceiverSpeaker:
          .speakers
        default: .unknown
        }
      })
  }

  private static func combine(_ kinds: [OutputKind]) -> OutputKind {
    if kinds.contains(.speakers) { return .speakers }
    if !kinds.isEmpty && kinds.allSatisfy({ $0 == .headphones }) { return .headphones }
    return .unknown
  }
}
