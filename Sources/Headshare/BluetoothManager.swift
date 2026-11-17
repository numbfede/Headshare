import Foundation
import IOBluetooth

struct PairedDevice: Identifiable, Hashable {
    let id: String      // Bluetooth address
    let name: String
    let isConnected: Bool
}

final class BluetoothManager {
    private var pending: [String: ConnectTarget] = [:]

    func pairedAudioDevices() -> [PairedDevice] {
        guard let list = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return [] }
        let audioMajor = BluetoothDeviceClassMajor(kBluetoothDeviceClassMajorAudio)
        return list.compactMap { d -> PairedDevice? in
            guard d.deviceClassMajor == audioMajor, let addr = d.addressString else { return nil }
            let name: String = d.name ?? addr
            return PairedDevice(id: addr, name: name, isConnected: d.isConnected())
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Asynchronous connect on the main run loop (IOBluetooth is not thread-safe).
    func connect(address: String, completion: @escaping (Bool) -> Void) {
        guard pending[address] == nil, let device = IOBluetoothDevice(addressString: address) else {
            completion(false); return
        }
        let target = ConnectTarget { [weak self] ok in
            guard self?.pending.removeValue(forKey: address) != nil else { return }
            completion(ok)
        }
        pending[address] = target
        if device.openConnection(target) != 0 {
            pending.removeValue(forKey: address)
            completion(false)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { target.finish(device.isConnected()) }
    }
}

private final class ConnectTarget: NSObject {
    private var done: ((Bool) -> Void)?
    init(_ done: @escaping (Bool) -> Void) { self.done = done }

    func finish(_ ok: Bool) {
        let d = done
        done = nil
        d?(ok)
    }

    // Informal IOBluetoothDevice async callback.
    @objc func connectionComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        finish(status == 0)
    }
}
