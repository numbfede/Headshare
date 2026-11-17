import CoreAudio
import Foundation

struct OutputDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let transport: UInt32

    var isBluetooth: Bool {
        transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE
    }

    var isVirtual: Bool { transport == kAudioDeviceTransportTypeVirtual }

    var symbol: String {
        switch transport {
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return "headphones"
        case kAudioDeviceTransportTypeBuiltIn: return "laptopcomputer"
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort: return "display"
        case kAudioDeviceTransportTypeUSB, kAudioDeviceTransportTypeThunderbolt: return "cable.connector"
        case kAudioDeviceTransportTypeAirPlay: return "airplayaudio"
        case kAudioDeviceTransportTypeVirtual: return "waveform"
        default: return "hifispeaker"
        }
    }

    var transportName: String {
        switch transport {
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return "Bluetooth"
        case kAudioDeviceTransportTypeBuiltIn: return String(localized: "Built-in")
        case kAudioDeviceTransportTypeUSB: return "USB"
        case kAudioDeviceTransportTypeThunderbolt: return "Thunderbolt"
        case kAudioDeviceTransportTypeHDMI: return "HDMI"
        case kAudioDeviceTransportTypeDisplayPort: return "DisplayPort"
        case kAudioDeviceTransportTypeAirPlay: return "AirPlay"
        case kAudioDeviceTransportTypeVirtual: return String(localized: "Virtual")
        default: return String(localized: "Audio device")
        }
    }
}

/// Thin wrapper over the public CoreAudio HAL API. No drivers, no kexts.
enum AudioSystem {
    static let system = AudioObjectID(kAudioObjectSystemObject)

    static func address(_ selector: AudioObjectPropertySelector,
                        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    // MARK: Enumeration

    static func allDeviceIDs() -> [AudioDeviceID] {
        var addr = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    static func string(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr, let v = value else { return nil }
        return v.takeRetainedValue() as String
    }

    static func uint32(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32? {
        var addr = address(selector)
        var v: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &v) == noErr else { return nil }
        return v
    }

    static func uid(_ id: AudioDeviceID) -> String? { string(id, kAudioDevicePropertyDeviceUID) }
    static func transport(_ id: AudioDeviceID) -> UInt32 { uint32(id, kAudioDevicePropertyTransportType) ?? 0 }

    static func hasStreams(_ id: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        var addr = address(kAudioDevicePropertyStreams, scope: scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr else { return false }
        return size > 0
    }

    static func outputDevices() -> [OutputDevice] {
        allDeviceIDs().compactMap { id in
            guard hasStreams(id, scope: kAudioObjectPropertyScopeOutput),
                  let uid = uid(id) else { return nil }
            let t = transport(id)
            if t == kAudioDeviceTransportTypeAggregate { return nil }
            if (uint32(id, kAudioDevicePropertyIsHidden) ?? 0) != 0 { return nil }
            let name = string(id, kAudioObjectPropertyName) ?? uid
            return OutputDevice(id: id, uid: uid, name: name, transport: t)
        }
    }

    static func deviceID(forUID uid: String) -> AudioDeviceID? {
        allDeviceIDs().first { self.uid($0) == uid }
    }

    static func builtInDevice(scope: AudioObjectPropertyScope) -> AudioDeviceID? {
        allDeviceIDs().first { transport($0) == kAudioDeviceTransportTypeBuiltIn && hasStreams($0, scope: scope) }
    }

    static func sampleRate(_ id: AudioDeviceID) -> Double {
        var addr = address(kAudioDevicePropertyNominalSampleRate)
        var v: Float64 = 0
        var size = UInt32(MemoryLayout<Float64>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &v) == noErr, v > 0 else { return 48_000 }
        return v
    }

    // MARK: Default devices

    static func defaultDevice(_ selector: AudioObjectPropertySelector) -> AudioDeviceID {
        var addr = address(selector)
        var id: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &id)
        return id
    }

    @discardableResult
    static func setDefaultDevice(_ selector: AudioObjectPropertySelector, _ id: AudioDeviceID) -> Bool {
        var addr = address(selector)
        var value = id
        return AudioObjectSetPropertyData(system, &addr, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &value) == noErr
    }

    // MARK: Volume

    private static func volumeAddresses(_ id: AudioDeviceID) -> [AudioObjectPropertyAddress] {
        var main = address(kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeOutput)
        if AudioObjectHasProperty(id, &main) { return [main] }
        var result: [AudioObjectPropertyAddress] = []
        for ch: UInt32 in 1...2 {
            var a = address(kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeOutput, element: ch)
            if AudioObjectHasProperty(id, &a) { result.append(a) }
        }
        return result
    }

    static func isVolumeSettable(_ id: AudioDeviceID) -> Bool {
        let addrs = volumeAddresses(id)
        guard !addrs.isEmpty else { return false }
        return addrs.allSatisfy { a in
            var a = a
            var settable: DarwinBoolean = false
            return AudioObjectIsPropertySettable(id, &a, &settable) == noErr && settable.boolValue
        }
    }

    static func volume(_ id: AudioDeviceID) -> Float? {
        let values: [Float] = volumeAddresses(id).compactMap { a in
            var a = a
            var v: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            return AudioObjectGetPropertyData(id, &a, 0, nil, &size, &v) == noErr ? v : nil
        }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Float(values.count)
    }

    static func setVolume(_ id: AudioDeviceID, _ value: Float) {
        for a in volumeAddresses(id) {
            var a = a
            var v = Float32(max(0, min(1, value)))
            AudioObjectSetPropertyData(id, &a, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
        }
    }

    // MARK: Aggregate (multi-output) device

    struct SubDevice { let uid: String; let latencyFrames: Int }

    static func createAggregate(uid: String, name: String, clockUID: String, subdevices: [SubDevice]) -> AudioDeviceID? {
        let subs: [[String: Any]] = subdevices.map { s in
            var d: [String: Any] = [kAudioSubDeviceUIDKey: s.uid]
            if s.uid != clockUID { d[kAudioSubDeviceDriftCompensationKey] = 1 }
            if s.latencyFrames > 0 { d[kAudioSubDeviceExtraOutputLatencyKey] = s.latencyFrames }
            return d
        }
        let desc: [String: Any] = [
            kAudioAggregateDeviceNameKey: name,
            kAudioAggregateDeviceUIDKey: uid,
            kAudioAggregateDeviceSubDeviceListKey: subs,
            kAudioAggregateDeviceMainSubDeviceKey: clockUID,
            kAudioAggregateDeviceClockDeviceKey: clockUID,
            kAudioAggregateDeviceIsStackedKey: 1,   // multi-output: every sub-device plays the same stream
            kAudioAggregateDeviceIsPrivateKey: 0,   // must be public to become the system default output
        ]
        var id: AudioDeviceID = 0
        let err = AudioHardwareCreateAggregateDevice(desc as CFDictionary, &id)
        return err == noErr && id != 0 ? id : nil
    }

    static func destroyAggregate(_ id: AudioDeviceID) {
        guard id != 0 else { return }
        AudioHardwareDestroyAggregateDevice(id)
    }

    /// Live-updates the extra latency of one sub-device without rebuilding the aggregate.
    static func setSubDeviceLatency(aggregate: AudioDeviceID, uid: String, frames: Double) -> Bool {
        var addr = address(kAudioObjectPropertyOwnedObjects)
        var qualifier: AudioClassID = kAudioSubDeviceClassID
        let qSize = UInt32(MemoryLayout<AudioClassID>.size)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(aggregate, &addr, qSize, &qualifier, &size) == noErr, size > 0 else { return false }
        var objects = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(aggregate, &addr, qSize, &qualifier, &size, &objects) == noErr else { return false }
        guard let sub = objects.first(where: { self.uid($0) == uid }) else { return false }
        var latAddr = address(kAudioSubDevicePropertyExtraLatency)
        var value = Float64(frames)
        return AudioObjectSetPropertyData(sub, &latAddr, 0, nil, UInt32(MemoryLayout<Float64>.size), &value) == noErr
    }

    // MARK: Listeners

    static func listen(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, _ handler: @escaping () -> Void) {
        var addr = address(selector)
        AudioObjectAddPropertyListenerBlock(object, &addr, DispatchQueue.main) { _, _ in handler() }
    }
}
