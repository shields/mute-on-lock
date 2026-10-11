// Copyright © 2026 Michael Shields
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Testing

struct DistributedObserverTests {
  @Test func receivesNotificationsFromAnotherProcess() throws {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let temporary = FileManager.default.temporaryDirectory
      .appendingPathComponent("mute-on-lock-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporary) }
    let executable = temporary.appendingPathComponent("notification-probe")
    try run(
      "/usr/bin/xcrun",
      arguments: [
        "swiftc", "-swift-version", "6", "-warnings-as-errors", "-parse-as-library",
        root.appendingPathComponent("Sources/LockAudio/DistributedObserver.swift").path,
        root.appendingPathComponent("tools/DistributedNotificationProbe.swift").path,
        "-o", executable.path,
      ])
    try run(executable.path, arguments: [])
  }

  private func run(_ executable: String, arguments: [String]) throws {
    let process = Process()
    let errors = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardError = errors
    try process.run()
    process.waitUntilExit()
    let error = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    try #require(process.terminationStatus == 0, "\(error)")
  }
}
