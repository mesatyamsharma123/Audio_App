import Foundation
import WebRTC
import AVFoundation

final class WebRTCManager: NSObject {
    
    static let shared = WebRTCManager()
    
    private var peerConnection: RTCPeerConnection?
    private var localAudioTrack: RTCAudioTrack?
    private var remoteAudioTrack: RTCAudioTrack?
    private var factory: RTCPeerConnectionFactory!
    
    override init() {
        super.init()
        RTCInitializeSSL()
        factory = RTCPeerConnectionFactory()
    }
    
    // MARK: - Peer Connection
    func setupPeerConnection() {
        let config = RTCConfiguration()
        config.sdpSemantics = .unifiedPlan
        config.iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil,
                                              optionalConstraints: ["DtlsSrtpKeyAgreement": "true"])
        
        peerConnection = factory.peerConnection(with: config, constraints: constraints, delegate: self)
        print("✅ PeerConnection created")
    }
    
    // MARK: - Local Audio
    func startLocalAudio() {
        let audioSource = factory.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil))
        localAudioTrack = factory.audioTrack(with: audioSource, trackId: "ARDAMSa0")
        
        if let track = localAudioTrack {
            peerConnection?.add(track, streamIds: ["stream0"])
            print("✅ Local audio track added")
        }
    }
    
    // MARK: - Offer / Answer
    func createOffer() {
        let constraints = RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveAudio": "true"], optionalConstraints: nil)
        Task { [weak self] in
            guard let self = self, let peerConnection = self.peerConnection else { return }
            do {
                let sdp = try await peerConnection.offer(for: constraints)
                try await peerConnection.setLocalDescription(sdp)
                SignalingManager.shared.sendSDP(sdp)
            } catch {
                print("❌ Failed to create offer:", error.localizedDescription)
            }
        }
    }
    
    func createAnswer() {
        let constraints = RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveAudio": "true"], optionalConstraints: nil)
        Task { [weak self] in
            guard let self = self, let peerConnection = self.peerConnection else { return }
            do {
                let sdp = try await peerConnection.answer(for: constraints)
                try await peerConnection.setLocalDescription(sdp)
                SignalingManager.shared.sendSDP(sdp)
            } catch {
                print("❌ Failed to create answer:", error.localizedDescription)
            }
        }
    }
    
    // MARK: - Remote SDP
    func setRemoteDescription(_ sdp: RTCSessionDescription) {
        Task { [weak self] in
            guard let self = self, let peerConnection = self.peerConnection else { return }
            do {
                try await peerConnection.setRemoteDescription(sdp)
            } catch {
                print("❌ Failed to set remote description:", error)
            }
        }
    }
    
    // MARK: - ICE Candidate
    func addIceCandidate(_ candidate: RTCIceCandidate) {
        peerConnection?.add(candidate)
    }
}

// MARK: - RTCPeerConnectionDelegate
extension WebRTCManager: RTCPeerConnectionDelegate {
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("✅ Remote stream received")
        if let audioTrack = stream.audioTracks.first {
            self.remoteAudioTrack = audioTrack
            audioTrack.isEnabled = true
            print("✅ Remote audio track enabled")
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("❌ Remote stream removed")
        self.remoteAudioTrack = nil
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("ICE state:", newState.rawValue)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        print("✅ ICE candidate generated:", candidate.sdp)
        SignalingManager.shared.sendCandidate(candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
