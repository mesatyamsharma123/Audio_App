import Foundation
import AVFoundation
import Combine
import WebRTC

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
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.callState = .searching }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.callState = .matched }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                self.callState = .inCall
                self.setupAudioSession()
                self.startAudioEngine()
                
                // Start WebRTC
                WebRTCManager.shared.setupPeerConnection()
                WebRTCManager.shared.startLocalAudio()
                
                // Connect signaling
                SignalingManager.shared.connect()
            }
        }
    }
    
    // MARK: - End Call
    func endCall() {
        stopAudio()
        WebRTCManager.shared.closeConnection()
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
        WebRTCManager.shared.closeConnection()
        callState = .idle
    }
    
    // MARK: - Mute / Speaker
    func toggleMute() {
        isMuted.toggle()
        WebRTCManager.shared.localAudioTrack?.isEnabled = !isMuted
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
