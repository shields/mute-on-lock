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

import ArgumentParser
import BuildInfo
import Foundation
import LockAudio

@main
struct MuteOnLock: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "mute-on-lock",
    abstract: "Mute speaker and unidentified outputs when the screen locks.",
    version: "\(BuildInfo.version) (\(BuildInfo.revision))",
    subcommands: [Run.self, Check.self, Override.self])

  struct Run: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Run the login service.")

    func run() throws {
      try MainActor.assumeIsolated {
        let service = try SessionService()
        try service.start()
        withExtendedLifetime(service) { RunLoop.main.run() }
        try service.stop()
      }
    }
  }

  struct Check: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Report the session and default outputs without changing audio.")

    func run() throws {
      try MainActor.assumeIsolated {
        print("Screen locked: \(try SessionService.isLocked())")
        let audio = CoreAudioAccess(overrides: try OutputPreferences().overrides())
        var visited: Set<UInt32> = []
        for device in try audio.defaultOutputs()
        where device != 0 && visited.insert(device).inserted {
          let transport = try audio.transport(of: device)
          print("\(try audio.name(of: device)) [\(device)]: \(transport)")
          let kind = try audio.outputKind(of: device)
          print("  UID: \(try audio.uid(of: device))")
          print("  Type: \(kind.rawValue)")
          if kind == .headphones {
            print("  Exempt; no mute controls read or written")
          } else {
            for control in try audio.muteControls(of: device) {
              print(
                "  Mute element \(control): \(try audio.isMuted(device: device, control: control))")
            }
          }
        }
      }
    }
  }
  struct Override: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Set a device type override; auto removes it.")

    enum Kind: String, ExpressibleByArgument, CaseIterable {
      case headphones
      case speakers
      case auto
    }

    @Argument(help: "Stable device UID shown by check.") var uid: String
    @Argument(help: "headphones, speakers, or auto.") var kind: Kind

    func run() throws {
      try MainActor.assumeIsolated {
        try OutputPreferences().set(uid: uid, kind: OutputKind(rawValue: kind.rawValue))
        print("Override for \(uid): \(kind.rawValue). Restart the service to apply.")
      }
    }
  }

}
