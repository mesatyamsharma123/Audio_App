import Foundation
import WebRTC
import AVFoundation

final class WebRTCManager: NSObject, RTCPeerConnectionDelegate {
    
    static let shared = WebRTCManager()
    
    private var peerConnection: RTCPeerConnection?
    private var factory: RTCPeerConnectionFactory!
    
    private(set) var localAudioTrack: RTCAudioTrack?
    private(set) var remoteAudioTrack: RTCAudioTrack?
    
    override init() {
        super.init()
        RTCInitializeSSL()
        factory = RTCPeerConnectionFactory()
    }
    
    // MARK: - Peer Connection
    func setupPeerConnection() {
        let config = RTCConfiguration()
        config.sdpSemantics = .unifiedPlan
        config.iceServers = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])
        ]
        
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )
        
        peerConnection = factory.peerConnection(with: config, constraints: constraints, delegate: self)
        print("✅ PeerConnection created")
    }
    
    // MARK: - Local Audio
    func startLocalAudio() {
        let audioSource = factory.audioSource(
            with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        )
        localAudioTrack = factory.audioTrack(with: audioSource, trackId: "audio0")
        
        if let track = localAudioTrack {
            peerConnection?.add(track, streamIds: ["stream0"])
            print("✅ Local audio track added")
        }
    }
    
    // MARK: - Offer / Answer
    func createOffer() {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "true"],
            optionalConstraints: nil
        )
        
        peerConnection?.offer(for: constraints, completionHandler: { [weak self] sdp, error in
            guard let self = self, let sdp = sdp else {
                print("❌ Offer failed:", error?.localizedDescription ?? "unknown error")
                return
            }
            self.peerConnection?.setLocalDescription(sdp, completionHandler: { error in
                if let error = error {
                    print("❌ Failed to set local description:", error)
                } else {
                    print("✅ Local SDP set")
                    SignalingManager.shared.sendSDP(sdp)
                }
            })
        })
    }
    
    func createAnswer() {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "true"],
            optionalConstraints: nil
        )
        
        peerConnection?.answer(for: constraints, completionHandler: { [weak self] sdp, error in
            guard let self = self, let sdp = sdp else {
                print("❌ Answer failed:", error?.localizedDescription ?? "unknown error")
                return
            }
            self.peerConnection?.setLocalDescription(sdp, completionHandler: { error in
                if let error = error {
                    print("❌ Failed to set local description:", error)
                } else {
                    print("✅ Local SDP set (answer)")
                    SignalingManager.shared.sendSDP(sdp)
                }
            })
        })
    }
    
    // MARK: - Remote SDP
    func setRemoteDescription(_ sdp: RTCSessionDescription) {
        peerConnection?.setRemoteDescription(sdp, completionHandler: { error in
            if let error = error {
                print("❌ Failed to set remote SDP:", error)
            } else {
                print("✅ Remote SDP set")
            }
        })
    }
    
    // MARK: - ICE Candidate
    func addIceCandidate(_ candidate: RTCIceCandidate) {
        peerConnection?.add(candidate)
    }
    
    // MARK: - Close
    func closeConnection() {
        peerConnection?.close()
        peerConnection = nil
        localAudioTrack = nil
        remoteAudioTrack = nil
    }
    
    // MARK: - RTCPeerConnectionDelegate
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
