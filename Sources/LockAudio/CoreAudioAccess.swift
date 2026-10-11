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

import CoreAudio
import Foundation

@MainActor
public final class CoreAudioAccess: AudioAccess {
  private let overrides: [String: OutputKind]

  public init(overrides: [String: OutputKind] = [:]) { self.overrides = overrides }

  public func outputKind(of device: UInt32) throws -> OutputKind {
    if let kind = overrides[try uid(of: device)] { return kind }
    let terminals = try outputStreams(of: device).map { stream in
      var value: UInt32 = 0
      if hasProperty(object: stream, selector: kAudioStreamPropertyTerminalType) {
        try read(object: stream, selector: kAudioStreamPropertyTerminalType, value: &value)
      }
      return value
    }
    let sources: [UInt32]
    if try transport(of: device) == .other(kAudioDeviceTransportTypeBuiltIn) {
      sources = try values(
        object: device, selector: kAudioDevicePropertyDataSource,
        scope: kAudioDevicePropertyScopeOutput)
    } else {
      sources = []
    }
    return OutputClassifier.resolve(terminals: terminals, builtinSources: sources)
  }

  public func outputStreams(of device: UInt32) throws -> [UInt32] {
    try values(
      object: device, selector: kAudioDevicePropertyStreams, scope: kAudioDevicePropertyScopeOutput)
  }

  public func uid(of device: UInt32) throws -> String {
    try string(object: device, selector: kAudioDevicePropertyDeviceUID)
  }

  public func hasProperty(
    object: UInt32, selector: UInt32, scope: UInt32 = kAudioObjectPropertyScopeGlobal
  ) -> Bool {
    var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: 0)
    return AudioObjectHasProperty(object, &address)
  }

  private func values(object: UInt32, selector: UInt32, scope: UInt32) throws -> [UInt32] {
    var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: 0)
    guard AudioObjectHasProperty(object, &address) else { return [] }
    var size: UInt32 = 0
    try check(
      AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size),
      operation: "Read property size")
    guard size > 0 else { return [] }
    guard size % UInt32(MemoryLayout<UInt32>.size) == 0 else {
      throw AudioFailure.status(
        operation: "Invalid property size", code: kAudioHardwareIllegalOperationError)
    }
    var result = [UInt32](repeating: 0, count: Int(size) / MemoryLayout<UInt32>.size)
    try result.withUnsafeMutableBytes { bytes in
      try check(
        AudioObjectGetPropertyData(object, &address, 0, nil, &size, bytes.baseAddress!),
        operation: "Read property values")
    }
    return Array(result.prefix(Int(size) / MemoryLayout<UInt32>.size))
  }

  public func defaultOutputs() throws -> [UInt32] {
    try [
      kAudioHardwarePropertyDefaultOutputDevice, kAudioHardwarePropertyDefaultSystemOutputDevice,
    ]
    .map { selector in
      var device: UInt32 = 0
      try read(
        object: AudioObjectID(kAudioObjectSystemObject), selector: selector,
        scope: kAudioObjectPropertyScopeGlobal, value: &device)
      return device
    }
  }

  public func transport(of device: UInt32) throws -> Transport {
    guard hasProperty(object: device, selector: kAudioDevicePropertyTransportType) else {
      return .other(0)
    }
    var value: UInt32 = 0
    try read(object: device, selector: kAudioDevicePropertyTransportType, value: &value)
    return switch value {
    case kAudioDeviceTransportTypeBluetooth: .bluetooth
    case kAudioDeviceTransportTypeBluetoothLE: .bluetoothLE
    default: .other(value)
    }
  }

  public func name(of device: UInt32) throws -> String {
    try string(object: device, selector: kAudioObjectPropertyName)
  }

  private func string(object: UInt32, selector: UInt32) throws -> String {
    var value: Unmanaged<CFString>?
    try read(object: object, selector: selector, value: &value)
    guard let value else {
      throw AudioFailure.status(
        operation: "Read empty string property", code: kAudioHardwareIllegalOperationError)
    }
    return value.takeRetainedValue() as String
  }

  public func muteControls(of device: UInt32) throws -> [UInt32] {
    try MuteControlPlan.resolve(
      device: device,
      writable: { try self.writableMute(device: device, element: $0) },
      channels: { try self.channelCount(of: device) })
  }

  public func isMuted(device: UInt32, control: UInt32) throws -> Bool {
    var value: UInt32 = 0
    try read(
      object: device, selector: kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput,
      element: control, value: &value)
    return value != 0
  }

  public func mute(device: UInt32, control: UInt32) throws {
    var address = muteAddress(element: control)
    var value: UInt32 = 1
    try check(
      AudioObjectSetPropertyData(
        device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value),
      operation: "Mute output \(device), element \(control)")
  }

  public func isDisappearingDevice(_ error: any Error) -> Bool {
    guard case AudioFailure.status(_, let code) = error else { return false }
    return code == kAudioHardwareBadObjectError || code == kAudioHardwareBadDeviceError
  }

  private func writableMute(device: UInt32, element: UInt32) throws -> Bool {
    var address = muteAddress(element: element)
    guard AudioObjectHasProperty(device, &address) else { return false }
    var writable: DarwinBoolean = false
    try check(
      AudioObjectIsPropertySettable(device, &address, &writable), operation: "Read mute capability")
    return writable.boolValue
  }

  private func channelCount(of device: UInt32) throws -> UInt32 {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyStreamConfiguration,
      mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
    var size: UInt32 = 0
    try check(
      AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size), operation: "Read stream size"
    )
    guard size >= MemoryLayout<AudioBufferList>.size else {
      throw AudioFailure.unsupported(device: device)
    }
    let storage = UnsafeMutableRawPointer.allocate(
      byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
    defer { storage.deallocate() }
    try check(
      AudioObjectGetPropertyData(device, &address, 0, nil, &size, storage),
      operation: "Read stream configuration")
    let buffers = UnsafeMutableAudioBufferListPointer(
      storage.bindMemory(to: AudioBufferList.self, capacity: 1))
    return buffers.reduce(0) { $0 + $1.mNumberChannels }
  }

  private func muteAddress(element: UInt32) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeOutput,
      mElement: element)
  }

  private func read<T>(
    object: UInt32, selector: UInt32, scope: UInt32 = kAudioObjectPropertyScopeGlobal,
    element: UInt32 = kAudioObjectPropertyElementMain, value: inout T
  ) throws {
    var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    var size = UInt32(MemoryLayout<T>.size)
    try withUnsafeMutablePointer(to: &value) { pointer in
      try check(
        AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer),
        operation: "Read property \(selector) on output \(object)")
    }
  }

  public func check(_ status: OSStatus, operation: String) throws {
    guard status == noErr else { throw AudioFailure.status(operation: operation, code: status) }
  }
}
