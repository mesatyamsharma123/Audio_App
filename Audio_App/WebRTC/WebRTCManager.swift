import Foundation
import WebRTC

final class WebRTCManager: NSObject, RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
    
    }
    

    static let shared = WebRTCManager()

    private var peerConnection: RTCPeerConnection?
    private let factory = RTCPeerConnectionFactory()

    private(set) var localAudioTrack: RTCAudioTrack?
    private(set) var remoteAudioTrack: RTCAudioTrack?

    @MainActor
    func setupPeerConnection() {
        let config = RTCConfiguration()
        config.sdpSemantics = .unifiedPlan
        config.iceServers = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])
        ]

        peerConnection = factory.peerConnection(
            with: config,
            constraints: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil),
            delegate: self
        )

        addLocalAudioTrack()
    }

    @MainActor
    private func addLocalAudioTrack() {
        let source = factory.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil))
        localAudioTrack = factory.audioTrack(with: source, trackId: "audio0")
        peerConnection?.add(localAudioTrack!, streamIds: ["stream0"])
    }

    @MainActor
    func createOffer() async throws {
        guard let peerConnection else { return }
        // Create offer
        let sdp = try await peerConnection.offer(for: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil))
        // Set local description
        try await peerConnection.setLocalDescription(sdp)
        // Send via signaling
        try await SignalingManager.shared.sendSDP(sdp)
    }

    // Convenience wrappers for existing call sites
    func createOfferSync() {
        Task { @MainActor in
            try? await self.createOffer()
        }
    }

    @MainActor
    func createAnswer() async throws {
        guard let peerConnection else { return }
        let sdp = try await peerConnection.answer(for: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil))
        try await peerConnection.setLocalDescription(sdp)
        try await SignalingManager.shared.sendSDP(sdp)
    }

    // Convenience wrappers for existing call sites
    func createAnswerSync() {
        Task { @MainActor in
            try? await self.createAnswer()
        }
    }

    @MainActor
    func setRemoteDescription(_ sdp: RTCSessionDescription) async throws {
        guard let peerConnection else { return }
        try await peerConnection.setRemoteDescription(sdp)
    }

    @MainActor
    func addIceCandidate(_ candidate: RTCIceCandidate) async throws {
        guard let peerConnection else { return }
        try await peerConnection.add(candidate)
    }

    // Convenience for legacy call sites that are not async yet
    func addIceCandidateSync(_ candidate: RTCIceCandidate) {
        Task { @MainActor in
            try? await self.addIceCandidate(candidate)
        }
    }

    @MainActor
    func closeConnection() {
        peerConnection?.close()
        peerConnection = nil
    }

    // MARK: - Delegate
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        // Handle renegotiation if needed
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        // Observe signaling state changes if needed
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        // Observe ICE connection state changes if needed
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        // Observe overall peer connection state changes if needed
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange localCandidate: RTCIceCandidate?) {
        // Deprecated in some versions; keep for protocol completeness where required
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        // Handle removed ICE candidates if needed
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        // Handle opened data channel if using data channels
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        // Unified Plan typically uses transceivers; stream callbacks may still occur
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        // Handle removed media stream if needed
    }

    func peerConnection(_ peerConnection: RTCPeerConnection,
                        didAdd rtpReceiver: RTCRtpReceiver,
                        streams: [RTCMediaStream]) {

        if let track = rtpReceiver.track as? RTCAudioTrack {
            remoteAudioTrack = track
            track.isEnabled = true
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection,
                        didGenerate candidate: RTCIceCandidate) {
        SignalingManager.shared.sendCandidate(candidate)
    }
}
