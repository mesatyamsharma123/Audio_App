import Foundation
import WebRTC
import AVFoundation

final class WebRTCManager: NSObject {
    
    static let shared = WebRTCManager()
    
    private var peerConnection: RTCPeerConnection?
    private var factory: RTCPeerConnectionFactory!
    
    var localAudioTrack: RTCAudioTrack?
    var remoteAudioTrack: RTCAudioTrack?
    
    // Callbacks
    var onRemoteAudioTrack: ((RTCAudioTrack) -> Void)?
    var onICECandidate: ((RTCIceCandidate) -> Void)?
    
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
        
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )
        
        peerConnection = factory.peerConnection(with: config, constraints: constraints, delegate: self)
        print("✅ PeerConnection created")
    }
    
    // MARK: - Local Audio
    func startLocalAudio() {
        let audioSource = factory.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil))
        localAudioTrack = factory.audioTrack(with: audioSource, trackId: "audio0")
        
        if let track = localAudioTrack {
            peerConnection?.add(track, streamIds: ["stream0"])
            print("✅ Local audio track added")
        }
    }
    
    // MARK: - Offer / Answer
    func createOffer() {
        guard let pc = peerConnection else { return }
        let constraints = RTCMediaConstraints(mandatoryConstraints: [
            "OfferToReceiveAudio": "true"
        ], optionalConstraints: nil)
        
        pc.offer(for: constraints) { [weak self] sdp, error in
            guard let self, let sdp = sdp, error == nil else { return }
            pc.setLocalDescription(sdp) { _ in }
            SignalingManager.shared.sendSDP(sdp)
        }
    }
    
    func createAnswer() {
        guard let pc = peerConnection else { return }
        let constraints = RTCMediaConstraints(mandatoryConstraints: [
            "OfferToReceiveAudio": "true"
        ], optionalConstraints: nil)
        
        pc.answer(for: constraints) { [weak self] sdp, error in
            guard let self, let sdp = sdp, error == nil else { return }
            pc.setLocalDescription(sdp) { _ in }
            SignalingManager.shared.sendSDP(sdp)
        }
    }
    
    func setRemoteDescription(_ sdp: RTCSessionDescription) {
        peerConnection?.setRemoteDescription(sdp) { error in
            if let error {
                print("❌ Failed to set remote description:", error)
            } else {
                print("✅ Remote description set")
            }
        }
    }
    
    func addIceCandidate(_ candidate: RTCIceCandidate) {
        peerConnection?.add(candidate)
    }
}

// MARK: - RTCPeerConnectionDelegate
extension WebRTCManager: RTCPeerConnectionDelegate {
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        print("✅ ICE candidate generated:", candidate.sdp)
        SignalingManager.shared.sendCandidate(candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection,
                        didAdd rtpReceiver: RTCRtpReceiver,
                        streams: [RTCMediaStream]) {
        if let audioTrack = rtpReceiver.track as? RTCAudioTrack {
            print("✅ Remote audio track received")
            self.remoteAudioTrack = audioTrack
            audioTrack.isEnabled = true
            self.onRemoteAudioTrack?(audioTrack)
        }
    }
    
    // Other delegate methods
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
