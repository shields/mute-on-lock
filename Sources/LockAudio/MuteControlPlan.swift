// Copyright © 2026 Michael Shields
// SPDX-License-Identifier: Apache-2.0

enum MuteControlPlan {
  static func resolve(
    device: UInt32, writable: (UInt32) throws -> Bool, channels: () throws -> UInt32
  ) throws -> [UInt32] {
    if try writable(0) { return [0] }
    let count = try channels()
    guard count > 0 else { throw AudioFailure.unsupported(device: device) }
    let controls = Array(1...count)
    for control in controls {
      guard try writable(control) else { throw AudioFailure.unsupported(device: device) }
    }
    return controls
  }
}
