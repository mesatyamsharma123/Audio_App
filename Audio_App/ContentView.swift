import SwiftUI

struct ContentView: View {
    
    @StateObject private var viewModel = CallViewModel()
    
    var body: some View {
        VStack {
            Spacer()
            
            switch viewModel.callState {
            case .idle:
                idleView
            case .connecting:
                loadingView(text: "Connecting…")
            case .searching:
                searchingView
            case .matched:
                loadingView(text: "Match found!\nConnecting audio…")
            case .inCall:
                inCallView
            case .ended:
                endedView
            }
            
            Spacer()
        }
        .padding()
        .animation(.easeInOut, value: viewModel.callState)
    }
}

// MARK: - Views
private extension ContentView {
    
    var idleView: some View {
        VStack(spacing: 20) {
            Text("🎧 Audio Chat")
                .font(.largeTitle)
                .bold()
            
            Text("Talk to someone instantly")
                .foregroundColor(.gray)
            
            Button {
                viewModel.startCall()
            } label: {
                Text("Start Audio Call")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
    }
    
    func loadingView(text: String) -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text(text)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
    }
    
    var searchingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Looking for someone to talk to…")
                .font(.headline)
            
            Button("Cancel") {
                viewModel.cancelSearch()
            }
            .foregroundColor(.red)
        }
    }
    
    var inCallView: some View {
        VStack(spacing: 40) {
            Text("Connected")
                .font(.headline)
                .foregroundColor(.green)
            
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 180, height: 180)
                .overlay(
                    Text("🎙️")
                        .font(.system(size: 60))
                )
            
            HStack(spacing: 30) {
                Button {
                    viewModel.toggleMute()
                } label: {
                    Image(systemName: viewModel.isMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.title)
                }
                
                Button {
                    viewModel.endCall()
                } label: {
                    Image(systemName: "phone.down.fill")
                        .font(.title)
                        .foregroundColor(.red)
                }
                
                Button {
                    viewModel.toggleSpeaker()
                } label: {
                    Image(systemName: viewModel.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.slash.fill")
                        .font(.title)
                }
            }
        }
        .padding()
        .alert("Microphone access required", isPresented: $viewModel.showPermissionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please enable microphone in Settings to make audio calls.")
        }
    }
    
    var endedView: some View {
        VStack(spacing: 20) {
            Text("Call Ended")
                .font(.title2)
                .bold()
            
            Button {
                viewModel.startCall() // <- fixed
            } label: {
                Text("Start New Call")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
    }
}

#Preview {
    ContentView()
}
