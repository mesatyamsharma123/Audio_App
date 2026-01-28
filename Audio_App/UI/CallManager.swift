//
//  CallManager.swift
//  Audio_App
//
//  Created by Satyam Sharma Chingari on 28/01/26.
//

import Foundation
import CallKit
import AVFoundation
import UIKit

final class CallManager: NSObject {
    static let shared = CallManager()

    private let controller = CXCallController()
    private let provider: CXProvider
    private var uuid: UUID?

    override init() {
        let config = CXProviderConfiguration(localizedName: "Audio Chat")
        config.supportsVideo = false
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.generic]
        config.includesCallsInRecents = false
        config.iconTemplateImageData = UIImage(systemName: "phone.fill")?.pngData()
        provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    // OUTGOING (shows system call UI)
    func start() {
        let id = UUID()
        uuid = id
        let handle = CXHandle(type: .generic, value: "Audio Call")
        let action = CXStartCallAction(call: id, handle: handle)
        Task {
            do {
                try await controller.request(CXTransaction(action: action))
            } catch {
                // If the request fails, clear the uuid so subsequent calls can retry
                uuid = nil
                print("CallManager.start() request failed: \(error)")
            }
        }
    }

    // END
    func end() {
        guard let id = uuid else { return }
        Task {
            do {
                try await controller.request(CXTransaction(action: CXEndCallAction(call: id)))
                uuid = nil
            } catch {
                print("CallManager.end() request failed: \(error)")
            }
        }
    }

    // OPTIONAL: fake incoming ring (no server)
    func fakeIncoming() {
        let id = UUID()
        uuid = id
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: "Unknown")
        if #available(iOS 18.0, *) {
            Task {
                do {
                    try await provider.reportNewIncomingCall(with: id, update: update)
                } catch {
                    print("CallManager.fakeIncoming() report failed: \(error)")
                }
            }
        } else {
            provider.reportNewIncomingCall(with: id, update: update) { error in
                if let error = error {
                    print("CallManager.fakeIncoming() report failed: \(error)")
                }
            }
        }
    }
}

extension CallManager: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {}

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
        try? s.setActive(true)
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        try? AVAudioSession.sharedInstance().setActive(false)
        action.fulfill()
    }
}
