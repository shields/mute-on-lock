// Copyright © 2026 Michael Shields
// SPDX-License-Identifier: Apache-2.0

import Foundation

@main
struct DistributedNotificationProbe {
  @MainActor static func main() throws {
    if CommandLine.arguments.count == 2 {
      DistributedNotificationCenter.default().postNotificationName(
        Notification.Name(CommandLine.arguments[1]), object: nil,
        userInfo: nil, deliverImmediately: true)
      return
    }
    let name = Notification.Name("dev.msrl.mute-on-lock.tests.\(UUID().uuidString)")
    var received = false
    let observer = DistributedObserver(actions: [name: { received = true }])
    observer.start()
    defer { observer.stop() }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
    process.arguments = [name.rawValue]
    try process.run()
    defer { if process.isRunning { process.terminate() } }
    let deadline = Date().addingTimeInterval(10)
    while Date() < deadline && (!received || process.isRunning) {
      RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }
    guard received && !process.isRunning && process.terminationStatus == 0 else {
      FileHandle.standardError.write(Data("Distributed notification delivery failed\n".utf8))
      exit(EXIT_FAILURE)
    }
  }
}
