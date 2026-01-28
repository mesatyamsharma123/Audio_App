import Foundation
import WebRTC
import Combine

final class SignalingManager: ObservableObject {
    
    static let shared = SignalingManager()
    
    private var webSocket: URLSessionWebSocketTask?
    
    func connect() {
        let url = URL(string: "wss://YOUR_NGROK_URL")! // Replace with your server
        webSocket = URLSession.shared.webSocketTask(with: url)
        webSocket?.resume()
        listen()
    }
    
    private func listen() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                default: break
                }
            case .failure(let error):
                print("WebSocket error:", error)
            }
            self?.listen()
        }
    }
    
    // Send SDP
    func sendSDP(_ sdp: RTCSessionDescription) {
        let type = sdp.type == .offer ? "offer" : "answer"
        let message: [String: Any] = ["type": type, "sdp": sdp.sdp]
        sendMessage(message)
    }
    
    // Send ICE candidate
    func sendCandidate(_ candidate: RTCIceCandidate) {
        let message: [String: Any] = [
            "type": "candidate",
            "candidate": candidate.sdp,
            "sdpMLineIndex": candidate.sdpMLineIndex,
            "sdpMid": candidate.sdpMid ?? ""
        ]
        sendMessage(message)
    }
    
    private func sendMessage(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let text = String(data: data, encoding: .utf8) else { return }
        
        webSocket?.send(.string(text)) { error in
            if let error = error { print("WebSocket send error:", error) }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = dict["type"] as? String else { return }
        
        switch type {
        case "offer":
            if let sdpStr = dict["sdp"] as? String {
                let sdp = RTCSessionDescription(type: .offer, sdp: sdpStr)
                WebRTCManager.shared.setRemoteDescription(sdp)
                WebRTCManager.shared.startLocalAudio()  // Add local audio AFTER setting remote
                WebRTCManager.shared.createAnswer()
            }
        case "answer":
            if let sdpStr = dict["sdp"] as? String {
                let sdp = RTCSessionDescription(type: .answer, sdp: sdpStr)
                WebRTCManager.shared.setRemoteDescription(sdp)
            }
        case "candidate":
            if let sdp = dict["candidate"] as? String,
               let sdpMLineIndex = dict["sdpMLineIndex"] as? Int32,
               let sdpMid = dict["sdpMid"] as? String {
                let candidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
                WebRTCManager.shared.addIceCandidate(candidate)
            }
        default: break
        }
    }
}
