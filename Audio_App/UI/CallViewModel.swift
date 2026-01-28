import Foundation
import AVFoundation
import Combine

enum CallState {
    case idle, connecting, searching, matched, inCall, ended
}

final class CallViewModel: ObservableObject {
    
    @Published var callState: CallState = .idle
    @Published var isMuted = false
    @Published var isSpeakerOn = false
    @Published var showPermissionAlert = false
    
    private let audioEngine = AVAudioEngine()
    private let session = AVAudioSession.sharedInstance()
    
    // MARK: - Start Call
    func startCall() {
        requestMicrophonePermission { granted in
            guard granted else {
                self.showPermissionAlert = true
                self.callState = .ended
                return
            }
            
            self.callState = .connecting
            
            // ✅ Connect signaling first
            SignalingManager.shared.connect()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // ✅ Setup peer connection
                WebRTCManager.shared.setupPeerConnection()
                WebRTCManager.shared.startLocalAudio()
                
                // ✅ Create offer
                WebRTCManager.shared.createOffer()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.callState = .inCall
            }
        }
    }

    
    // MARK: - End Call
    func endCall() {
        stopAudio()
        // CallManager.shared.end()  <-- uncomment if CallKit is ready
        callState = .ended
        isMuted = false
        isSpeakerOn = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.callState = .idle
        }
    }
    
    // MARK: - Cancel Search
    func cancelSearch() {
        stopAudio()
        callState = .idle
        // CallManager.shared.end() <-- if using CallKit
    }
    
    // MARK: - Mute / Speaker
    func toggleMute() {
        isMuted.toggle()
        audioEngine.inputNode.volume = isMuted ? 0 : 1
    }
    
    func toggleSpeaker() {
        isSpeakerOn.toggle()
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(isSpeakerOn ? .speaker : .none)
    }
    
    // MARK: - Audio Helpers
    private func requestMicrophonePermission(_ completion: @escaping (Bool) -> Void) {
        switch session.recordPermission {
        case .granted: completion(true)
        case .denied: completion(false)
        case .undetermined:
            session.requestRecordPermission { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        @unknown default: completion(false)
        }
    }
    
    private func setupAudioSession() {
        try? session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
        try? session.setActive(true)
    }
    
    private func startAudioEngine() {
        let input = audioEngine.inputNode
        audioEngine.connect(input, to: audioEngine.mainMixerNode, format: input.outputFormat(forBus: 0))
        try? audioEngine.start()
    }
    
    private func stopAudio() {
        audioEngine.stop()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }
}
