// Copyright © 2026 Michael Shields
// SPDX-License-Identifier: Apache-2.0

import AppKit
import CoreAudio
import CoreGraphics
import Foundation
import os

@MainActor
public final class SessionService {
  private struct Listener {
    let object: UInt32
    var address: AudioObjectPropertyAddress
    let block: AudioObjectPropertyListenerBlock
  }

  private let audio: CoreAudioAccess
  private let policy: LockPolicy
  private let logger = Logger(subsystem: "dev.msrl.mute-on-lock", category: "service")
  private var observers: [(NotificationCenter, NSObjectProtocol)] = []
  private var distributedObserver: DistributedObserver?
  private var hardwareListeners: [Listener] = []
  private var outputListeners: [Listener] = []

  public init() throws {
    audio = CoreAudioAccess(overrides: try OutputPreferences().overrides())
    policy = LockPolicy(audio: audio)
  }

  public static func isLocked() throws -> Bool {
    guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else {
      throw AudioFailure.noSession
    }
    return session["CGSSessionScreenIsLocked"] as? Bool ?? false
  }

  public func start() throws {
    distributedObserver = DistributedObserver(actions: [
      Notification.Name("com.apple.screenIsLocked"): { [weak self] in
        self?.handle {
          try self?.updateOutputs()
          try self?.policy.sessionChanged(locked: true)
        }
      },
      Notification.Name("com.apple.screenIsUnlocked"): { [weak self] in
        self?.handle { try self?.policy.sessionChanged(locked: false) }
      },
    ])
    distributedObserver?.start()
    observe(NSWorkspace.shared.notificationCenter, name: NSWorkspace.didWakeNotification.rawValue) {
      service in
      try service.updateOutputs(reconcile: false)
      try service.policy.sessionChanged(locked: Self.isLocked())
    }
    for selector in [
      kAudioHardwarePropertyDefaultOutputDevice, kAudioHardwarePropertyDefaultSystemOutputDevice,
      kAudioHardwarePropertyDevices,
    ] {
      hardwareListeners.append(
        try listen(object: UInt32(kAudioObjectSystemObject), selector: selector))
    }
    try updateOutputs()
    try policy.sessionChanged(locked: Self.isLocked())
    logger.info("Started; screen locked: \(self.policy.locked)")
  }

  public func stop() throws {
    distributedObserver?.stop()
    distributedObserver = nil
    for (center, observer) in observers { center.removeObserver(observer) }
    observers.removeAll()
    try remove(&outputListeners)
    try remove(&hardwareListeners)
  }

  private func updateOutputs(reconcile: Bool = true) throws {
    do {
      try subscribeOutputs()
    } catch {
      guard audio.isDisappearingDevice(error) else { throw error }
      try subscribeOutputs()
    }
    if reconcile { try policy.outputsChanged() }
  }

  private func subscribeOutputs() throws {
    try remove(&outputListeners)
    for device in Set(try audio.defaultOutputs()) where device != 0 {
      for selector in [kAudioDevicePropertyDataSource, kAudioDevicePropertyStreams] {
        if audio.hasProperty(
          object: device, selector: selector, scope: kAudioDevicePropertyScopeOutput)
        {
          outputListeners.append(
            try listen(object: device, selector: selector, scope: kAudioDevicePropertyScopeOutput))
        }
      }
      for stream in try audio.outputStreams(of: device) {
        if audio.hasProperty(object: stream, selector: kAudioStreamPropertyTerminalType) {
          outputListeners.append(
            try listen(object: stream, selector: kAudioStreamPropertyTerminalType))
        }
      }
    }
  }

  private func listen(
    object: UInt32, selector: UInt32, scope: UInt32 = kAudioObjectPropertyScopeGlobal
  ) throws -> Listener {
    var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: 0)
    let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      Task { @MainActor [weak self] in
        self?.handle { try self?.updateOutputs() }
      }
    }
    try audio.check(
      AudioObjectAddPropertyListenerBlock(object, &address, .main, block),
      operation: "Observe output classification")
    return Listener(object: object, address: address, block: block)
  }

  private func remove(_ listeners: inout [Listener]) throws {
    for var listener in listeners {
      let status = AudioObjectRemovePropertyListenerBlock(
        listener.object, &listener.address, .main, listener.block)
      if status != kAudioHardwareBadObjectError && status != kAudioHardwareBadDeviceError {
        try audio.check(status, operation: "Remove output observer")
      }
    }
    listeners.removeAll()
  }

  private func observe(
    _ center: NotificationCenter, name: String,
    action: @escaping @MainActor (SessionService) throws -> Void
  ) {
    let observer = center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) {
      [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.handle { try action(self) }
      }
    }
    observers.append((center, observer))
  }

  private func handle(_ action: () throws -> Void) {
    do {
      try action()
    } catch {
      logger.fault("\(String(describing: error), privacy: .public)")
      FileHandle.standardError.write(Data("mute-on-lock: \(error)\n".utf8))
      exit(EXIT_FAILURE)
    }
  }
}
