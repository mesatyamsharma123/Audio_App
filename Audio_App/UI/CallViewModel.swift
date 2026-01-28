import Foundation
import AVFoundation
import Combine

enum CallState {
    case idle
    case inCall
    case ended
}

enum CallRole {
    case caller
    case callee
}

final class CallViewModel: ObservableObject {

    @Published var callState: CallState = .idle
    @Published var isMuted = false
    @Published var isSpeakerOn = false
    @Published var showPermissionAlert = false

    private let audioSession = AVAudioSession.sharedInstance()
    private let role: CallRole

    // ✅ SAFE INIT (NO AUDIO / WEBRTC HERE)
    init(role: CallRole) {
        self.role = role
        print("CallViewModel init with role:", role)
    }

    // MARK: - Start Call
    func startCall() {
        requestMicrophonePermission { granted in
            guard granted else {
                DispatchQueue.main.async {
                    self.showPermissionAlert = true
                }
                return
            }

            DispatchQueue.main.async {
                self.setupAudioSession()
                self.callState = .inCall
                print("✅ Call started")
            }
        }
    }

    // MARK: - End Call
    func endCall() {
        DispatchQueue.main.async {
            self.callState = .ended
            self.isMuted = false
            self.isSpeakerOn = false
            self.deactivateAudio()
            print("❌ Call ended")
        }
    }

    // MARK: - Controls
    func toggleMute() {
        isMuted.toggle()
        print(isMuted ? "🔇 Muted" : "🎙️ Unmuted")
    }

    func toggleSpeaker() {
        isSpeakerOn.toggle()
        try? audioSession.overrideOutputAudioPort(
            isSpeakerOn ? .speaker : .none
        )
    }

    // MARK: - Audio
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.allowBluetooth, .defaultToSpeaker]
            )
            try audioSession.setActive(true)
            print("🔊 Audio session active")
        } catch {
            print("❌ Audio session error:", error)
        }
    }

    private func deactivateAudio() {
        try? audioSession.setActive(false)
    }

    // MARK: - Permission
    private func requestMicrophonePermission(
        _ completion: @escaping (Bool) -> Void
    ) {
        switch audioSession.recordPermission {
        case .granted:
            completion(true)
        case .denied:
            completion(false)
        case .undetermined:
            audioSession.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        @unknown default:
            completion(false)
        }
    }
}
