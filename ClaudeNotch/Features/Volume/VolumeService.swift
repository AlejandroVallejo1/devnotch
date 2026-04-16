import CoreAudio
import Foundation

/// Listens for system volume changes on the default output device and
/// reports the new level via `onChange`. Uses public CoreAudio APIs.
final class VolumeService {
    var onChange: ((Float) -> Void)?

    private var deviceID: AudioDeviceID = 0
    private var listenerBlocks: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []

    func start() {
        deviceID = defaultOutputDevice()
        guard deviceID != 0 else { return }
        addVolumeListeners()
    }

    private func defaultOutputDevice() -> AudioDeviceID {
        var id: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
        return id
    }

    /// We listen on both the master element (many devices expose it)
    /// and channels 1/2 as a fallback.
    private func addVolumeListeners() {
        let elements: [AudioObjectPropertyElement] = [
            kAudioObjectPropertyElementMain,  // master (== 0 in newer SDKs)
            1,
            2
        ]
        for element in elements {
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: element
            )
            guard AudioObjectHasProperty(deviceID, &addr) else { continue }
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                guard let self else { return }
                let level = self.readVolume()
                DispatchQueue.main.async {
                    self.onChange?(level)
                }
            }
            listenerBlocks.append((addr, block))
            AudioObjectAddPropertyListenerBlock(deviceID, &addr, DispatchQueue.main, block)
        }
    }

    private func readVolume() -> Float {
        let elements: [AudioObjectPropertyElement] = [kAudioObjectPropertyElementMain, 1, 2]
        for element in elements {
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: element
            )
            guard AudioObjectHasProperty(deviceID, &addr) else { continue }
            var value: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            let status = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &value)
            if status == noErr { return value }
        }
        return 0
    }
}
