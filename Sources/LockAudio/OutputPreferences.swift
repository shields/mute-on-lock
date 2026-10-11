// Copyright © 2026 Michael Shields
// SPDX-License-Identifier: Apache-2.0

import Foundation

public struct PreferenceFailure: Error, CustomStringConvertible {
  public let description: String
}

@MainActor
public struct OutputPreferences {
  public static let domain = "dev.msrl.mute-on-lock"
  private static let key = "deviceOverrides"
  private let defaults: UserDefaults

  public init(defaults: UserDefaults? = nil) {
    self.defaults = defaults ?? UserDefaults(suiteName: Self.domain)!
  }

  public func overrides() throws -> [String: OutputKind] {
    guard let value = defaults.object(forKey: Self.key) else { return [:] }
    guard let entries = value as? [String: String] else {
      throw PreferenceFailure(
        description: "deviceOverrides must be a dictionary of device UIDs and output types")
    }
    var result: [String: OutputKind] = [:]
    for (uid, type) in entries {
      guard !uid.isEmpty, let kind = OutputKind(rawValue: type), kind != .unknown else {
        throw PreferenceFailure(description: "Invalid output override for UID \(uid)")
      }
      result[uid] = kind
    }
    return result
  }

  public func set(uid: String, kind: OutputKind?) throws {
    guard !uid.isEmpty, kind != .unknown else {
      throw PreferenceFailure(
        description: "Overrides require a device UID and headphones, speakers, or auto")
    }
    var entries = try overrides()
    entries[uid] = kind
    defaults.set(entries.mapValues(\.rawValue), forKey: Self.key)
  }
}
