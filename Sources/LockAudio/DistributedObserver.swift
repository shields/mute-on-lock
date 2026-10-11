// Copyright © 2026 Michael Shields
// SPDX-License-Identifier: Apache-2.0

import Foundation

@MainActor
final class DistributedObserver: NSObject {
  private let actions: [Notification.Name: @MainActor () -> Void]

  init(actions: [Notification.Name: @MainActor () -> Void]) {
    self.actions = actions
    super.init()
  }

  func start() {
    let center = DistributedNotificationCenter.default()
    for name in actions.keys {
      center.addObserver(
        self, selector: #selector(receive(_:)), name: name, object: nil,
        suspensionBehavior: .deliverImmediately)
    }
  }

  func stop() {
    DistributedNotificationCenter.default().removeObserver(self)
  }

  @objc private func receive(_ notification: Notification) {
    actions[notification.name]?()
  }
}
