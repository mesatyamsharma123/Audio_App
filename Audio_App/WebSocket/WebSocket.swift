import Foundation
import WebRTC

final class SignalingManager {

    static let shared = SignalingManager()
    private var socket: URLSessionWebSocketTask?

    func connect() {
        let url = URL(string: "wss://07cf9938506f.ngrok-free.app")!
        socket = URLSession.shared.webSocketTask(with: url)
        socket?.resume()
        listen()
    }

    private func listen() {
        socket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                if case .string(let text) = message {
                    self?.handle(text)
                }
            case .failure(let error):
                // Optionally log the receive error
                print("WebSocket receive error: \(error)")
            }
            self?.listen()
        }
    }

    func sendSDP(_ sdp: RTCSessionDescription) {
        let msg: [String: Any] = [
            "type": sdp.type == .offer ? "offer" : "answer",
            "sdp": sdp.sdp
        ]
        send(msg)
    }

    func sendCandidate(_ c: RTCIceCandidate) {
        let msg: [String: Any] = [
            "type": "candidate",
            "candidate": c.sdp,
            "sdpMLineIndex": c.sdpMLineIndex,
            "sdpMid": c.sdpMid ?? ""
        ]
        send(msg)
    }

    private func send(_ msg: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: msg) else { return }
        let text = String(decoding: data, as: UTF8.self)
        // Use async send in a detached Task to avoid requiring async at call sites
        Task { [weak socket] in
            do {
                try await socket?.send(.string(text))
            } catch {
                // Optionally log or handle send error
                print("WebSocket send error: \(error)")
            }
        }
    }

    private func handle(_ text: String) {
        guard
            let data = text.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = json["type"] as? String
        else {
            print("Invalid signaling message: \(text)")
            return
        }

        switch type {
        case "offer":
            if let sdpString = json["sdp"] as? String {
                let sdp = RTCSessionDescription(type: .offer, sdp: sdpString)
                Task {
                    do {
                        try await WebRTCManager.shared.setRemoteDescription(sdp)
                        try await WebRTCManager.shared.createAnswer()
                    } catch {
                        print("Failed handling offer: \(error)")
                    }
                }
            }

        case "answer":
            if let sdpString = json["sdp"] as? String {
                let sdp = RTCSessionDescription(type: .answer, sdp: sdpString)
                Task {
                    do {
                        try await WebRTCManager.shared.setRemoteDescription(sdp)
                    } catch {
                        print("Failed setting remote answer: \(error)")
                    }
                }
            }

        case "candidate":
            if let candidate = json["candidate"] as? String,
               let index = json["sdpMLineIndex"] as? Int,
               let mid = json["sdpMid"] as? String? {
                let c = RTCIceCandidate(
                    sdp: candidate,
                    sdpMLineIndex: Int32(index),
                    sdpMid: mid
                )
                Task {
                    do {
                        try await WebRTCManager.shared.addIceCandidate(c)
                    } catch {
                        print("Failed adding ICE candidate: \(error)")
                    }
                }
            }

        default:
            break
        }
    }
}
