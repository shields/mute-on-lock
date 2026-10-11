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

import Foundation

public enum AudioFailure: Error, Equatable, CustomStringConvertible {
  case status(operation: String, code: Int32)
  case unsupported(device: UInt32)
  case noSession

  public var description: String {
    switch self {
    case .status(let operation, let code): "\(operation): CoreAudio status \(code)"
    case .unsupported(let device): "Output \(device) has no complete writable mute control"
    case .noSession: "Cannot read the current GUI session"
    }
  }
}

public enum Transport: Equatable, Sendable {
  case bluetooth
  case bluetoothLE
  case other(UInt32)

}

@MainActor
public protocol AudioAccess {
  func defaultOutputs() throws -> [UInt32]
  func outputKind(of device: UInt32) throws -> OutputKind
  func muteControls(of device: UInt32) throws -> [UInt32]
  func isMuted(device: UInt32, control: UInt32) throws -> Bool
  func mute(device: UInt32, control: UInt32) throws
  func isDisappearingDevice(_ error: any Error) -> Bool
}

@MainActor
public final class LockPolicy {
  public private(set) var locked = false
  private let audio: any AudioAccess

  public init(audio: any AudioAccess) { self.audio = audio }

  public func sessionChanged(locked: Bool) throws {
    self.locked = locked
    try outputsChanged()
  }

  public func outputsChanged() throws {
    guard locked else { return }
    do {
      try muteOutputs()
    } catch {
      guard audio.isDisappearingDevice(error) else { throw error }
      try muteOutputs()
    }
  }

  private func muteOutputs() throws {
    var visited: Set<UInt32> = []
    for device in try audio.defaultOutputs() where device != 0 && visited.insert(device).inserted {
      guard try audio.outputKind(of: device) != .headphones else { continue }
      let controls = try audio.muteControls(of: device)
      guard !controls.isEmpty else { throw AudioFailure.unsupported(device: device) }
      for control in controls where try !audio.isMuted(device: device, control: control) {
        try audio.mute(device: device, control: control)
      }
    }
  }
}
